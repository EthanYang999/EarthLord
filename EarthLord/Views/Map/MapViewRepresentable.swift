//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView 的 SwiftUI 包装器 - 显示末世风格地图和路径轨迹
//

import SwiftUI
import MapKit

/// MKMapView 的 SwiftUI 包装器
/// 显示卫星混合地图，应用末世滤镜效果，处理用户位置显示、地图居中和路径轨迹渲染
struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - Bindings

    /// 用户位置坐标（双向绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位（防止重复居中）
    @Binding var hasLocatedUser: Bool

    /// 路径坐标数组（WGS-84 原始坐标）
    @Binding var trackingPath: [CLLocationCoordinate2D]

    // MARK: - Properties

    /// 路径更新版本号（触发轨迹重绘）
    var pathUpdateVersion: Int

    /// 是否正在追踪
    var isTracking: Bool

    /// 路径是否已闭合（影响轨迹颜色和多边形显示）
    var isPathClosed: Bool

    /// 已加载的领地列表
    var territories: [Territory]

    /// 当前用户 ID（用于区分自己和他人的领地）
    var currentUserId: String?

    /// Day 22: POI 列表
    var pois: [POI]

    /// Day 22: 已搜刮的 POI ID 集合
    var scavengedPOIIds: Set<String>

    /// Day 26: 建筑列表
    var buildings: [PlayerBuilding]

    /// Day 26: 建筑模板（用于获取图标和颜色）
    var buildingTemplates: [BuildingTemplate]

    // MARK: - UIViewRepresentable

    /// 创建 MKMapView
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 配置地图类型：卫星图 + 道路标签（末世废土风格）
        mapView.mapType = .hybrid

        // 隐藏 POI 标签（商店、餐厅等）
        mapView.pointOfInterestFilter = .excludingAll

        // 隐藏 3D 建筑
        mapView.showsBuildings = false

        // 显示用户位置蓝点（关键！这会触发 MapKit 获取位置）
        mapView.showsUserLocation = true

        // 允许地图交互
        mapView.isZoomEnabled = true      // 允许缩放
        mapView.isScrollEnabled = true    // 允许拖动
        mapView.isRotateEnabled = true    // 允许旋转
        mapView.isPitchEnabled = true     // 允许倾斜

        // 设置代理（关键！否则 didUpdate userLocation 和 rendererFor 不会被调用）
        mapView.delegate = context.coordinator

        return mapView
    }

    /// 更新 MKMapView（SwiftUI 状态变化时调用）
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 关键：更新 Coordinator 的 parent 引用，否则版本号检查会用旧值
        context.coordinator.parent = self

        // 更新轨迹显示（传入闭环状态）
        context.coordinator.updateTrackingPath(on: uiView, with: trackingPath, isPathClosed: isPathClosed)

        // 更新领地显示
        context.coordinator.drawTerritories(on: uiView, territories: territories, currentUserId: currentUserId)

        // Day 22: 更新 POI 标记
        context.coordinator.updatePOIAnnotations(on: uiView, pois: pois, scavengedIds: scavengedPOIIds)

        // Day 26: 更新建筑标记
        context.coordinator.updateBuildingAnnotations(on: uiView, buildings: buildings, templates: buildingTemplates)
    }

    /// 创建 Coordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    /// Coordinator 类 - 处理 MKMapView 的代理回调
    class Coordinator: NSObject, MKMapViewDelegate {

        /// 父视图引用
        var parent: MapViewRepresentable

        /// 是否已完成首次居中（防止重复居中）
        private var hasInitialCentered = false

        /// 当前显示的轨迹线（用于更新时移除旧轨迹）
        private var currentPolyline: MKPolyline?

        /// 当前显示的多边形（闭环后填充区域）
        private var currentPolygon: MKPolygon?

        /// 上次更新的路径版本号（避免重复绘制）
        private var lastPathVersion: Int = -1

        /// 当前路径是否已闭合（用于渲染器判断颜色）
        private var isCurrentlyPathClosed: Bool = false

        /// 上次绘制的领地 ID 集合（避免重复绘制）
        private var lastTerritoryIds: Set<String> = []

        /// Day 22: 上次显示的 POI ID 集合
        private var lastPOIIds: Set<String> = []

        /// Day 22: 上次的已搜刮 POI ID 集合
        private var lastScavengedIds: Set<String> = []

        /// Day 26: 上次显示的建筑 ID 集合
        private var lastBuildingIds: Set<UUID> = []

        /// Day 26: 上次的建筑状态（用于检测状态变化）
        private var lastBuildingStatuses: [UUID: BuildingStatus] = [:]

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - 轨迹更新方法

        /// 更新轨迹显示
        /// - Parameters:
        ///   - mapView: 地图视图
        ///   - path: WGS-84 坐标数组
        ///   - isPathClosed: 路径是否已闭合
        func updateTrackingPath(on mapView: MKMapView, with path: [CLLocationCoordinate2D], isPathClosed: Bool) {
            // 检查是否需要更新（通过版本号判断）
            guard parent.pathUpdateVersion != lastPathVersion else { return }
            lastPathVersion = parent.pathUpdateVersion

            // 更新闭合状态
            isCurrentlyPathClosed = isPathClosed

            // 移除旧的轨迹线
            if let oldPolyline = currentPolyline {
                mapView.removeOverlay(oldPolyline)
                currentPolyline = nil
            }

            // 移除旧的多边形
            if let oldPolygon = currentPolygon {
                mapView.removeOverlay(oldPolygon)
                currentPolygon = nil
            }

            // 如果路径少于 2 个点，无法绘制线条
            guard path.count >= 2 else {
                print("📍 路径点不足，暂不绘制轨迹")
                return
            }

            // 关键：将 WGS-84 坐标转换为 GCJ-02 坐标
            // 这样轨迹才会显示在正确的位置，不会偏移 100-500 米
            let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02Array(path)

            // 创建新的轨迹线
            let polyline = MKPolyline(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)

            // 添加到地图
            mapView.addOverlay(polyline)
            currentPolyline = polyline

            // 如果路径已闭合且至少有 3 个点，创建多边形填充
            if isPathClosed && gcj02Coordinates.count >= 3 {
                let polygon = MKPolygon(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
                mapView.addOverlay(polygon, level: .aboveRoads)
                currentPolygon = polygon
                print("🟢 闭环区域已填充，共 \(gcj02Coordinates.count) 个顶点")
            }

            print("🗺️ 轨迹已更新，共 \(path.count) 个点，闭合状态: \(isPathClosed)")
        }

        // MARK: - 领地绘制方法

        /// 绘制已保存的领地
        /// - Parameters:
        ///   - mapView: 地图视图
        ///   - territories: 领地数据数组
        ///   - currentUserId: 当前用户 ID
        func drawTerritories(on mapView: MKMapView, territories: [Territory], currentUserId: String?) {
            // 获取当前领地 ID 集合
            let currentIds = Set(territories.map { $0.id })

            // 如果领地没有变化，不需要重绘
            guard currentIds != lastTerritoryIds else { return }
            lastTerritoryIds = currentIds

            // 移除旧的领地多边形（保留路径轨迹）
            let territoryOverlays = mapView.overlays.filter { overlay in
                if let polygon = overlay as? MKPolygon {
                    return polygon.title == "mine" || polygon.title == "others"
                }
                return false
            }
            mapView.removeOverlays(territoryOverlays)

            // 绘制每个领地
            for territory in territories {
                var coords = territory.toCoordinates()

                // 至少需要 3 个点才能绘制多边形
                guard coords.count >= 3 else { continue }

                // ⚠️ 中国大陆需要坐标转换：WGS-84 → GCJ-02
                coords = CoordinateConverter.wgs84ToGcj02Array(coords)

                let polygon = MKPolygon(coordinates: coords, count: coords.count)

                // ⚠️ 关键：比较 userId 时必须统一大小写！
                // 数据库存的是小写 UUID，但 iOS 的 uuidString 返回大写
                let isMine = territory.userId.lowercased() == currentUserId?.lowercased()
                polygon.title = isMine ? "mine" : "others"

                mapView.addOverlay(polygon, level: .aboveRoads)
            }

            print("🏴 已绘制 \(territories.count) 块领地")
        }

        // MARK: - Day 22: POI 标记方法

        /// 更新 POI 标记
        /// - Parameters:
        ///   - mapView: 地图视图
        ///   - pois: POI 列表
        ///   - scavengedIds: 已搜刮的 POI ID 集合
        func updatePOIAnnotations(on mapView: MKMapView, pois: [POI], scavengedIds: Set<String>) {
            // 获取当前 POI ID 集合
            let currentIds = Set(pois.map { $0.id })

            // 如果 POI 没有变化且搜刮状态没有变化，不需要更新
            guard currentIds != lastPOIIds || scavengedIds != lastScavengedIds else { return }
            lastPOIIds = currentIds
            lastScavengedIds = scavengedIds

            // 移除旧的 POI 标记
            let existingAnnotations = mapView.annotations.filter { $0 is POIAnnotation }
            mapView.removeAnnotations(existingAnnotations)

            // 如果没有 POI，直接返回
            guard !pois.isEmpty else { return }

            // 添加新的 POI 标记
            for poi in pois {
                // 坐标转换：WGS-84 → GCJ-02
                let gcj02Coord = CoordinateConverter.wgs84ToGcj02(poi.coordinate)

                let annotation = POIAnnotation(
                    poi: poi,
                    coordinate: gcj02Coord,
                    isScavenged: scavengedIds.contains(poi.id)
                )
                mapView.addAnnotation(annotation)
            }

            print("📍 已更新 \(pois.count) 个 POI 标记")
        }

        // MARK: - Day 26: 建筑标记方法

        /// 更新建筑标记
        /// - Parameters:
        ///   - mapView: 地图视图
        ///   - buildings: 建筑列表
        ///   - templates: 建筑模板列表
        func updateBuildingAnnotations(on mapView: MKMapView, buildings: [PlayerBuilding], templates: [BuildingTemplate]) {
            // 获取当前建筑 ID 集合
            let currentIds = Set(buildings.map { $0.id })

            // 获取当前建筑状态
            let currentStatuses = Dictionary(uniqueKeysWithValues: buildings.map { ($0.id, $0.status) })

            // 检查是否需要更新（建筑变化或状态变化）
            let needsUpdate = currentIds != lastBuildingIds ||
                              currentStatuses.values.sorted(by: { $0.rawValue < $1.rawValue }) !=
                              lastBuildingStatuses.values.sorted(by: { $0.rawValue < $1.rawValue })

            guard needsUpdate else { return }
            lastBuildingIds = currentIds
            lastBuildingStatuses = currentStatuses

            // 移除旧的建筑标记
            let existingAnnotations = mapView.annotations.filter { $0 is BuildingAnnotation }
            mapView.removeAnnotations(existingAnnotations)

            // 如果没有建筑，直接返回
            guard !buildings.isEmpty else { return }

            // 添加新的建筑标记
            for building in buildings {
                // 获取建筑坐标
                guard let coord = building.coordinate else { continue }

                // 注意：数据库中保存的已经是 GCJ-02 坐标，直接使用无需转换

                // 获取对应的模板
                let template = templates.first { $0.templateId == building.templateId }

                let annotation = BuildingAnnotation(
                    building: building,
                    coordinate: coord,
                    template: template
                )
                mapView.addAnnotation(annotation)
            }

            print("🏗️ 已更新 \(buildings.count) 个建筑标记")
        }

        // MARK: - MKMapViewDelegate

        /// 用户位置更新回调（关键方法！）
        /// 首次获得位置时自动居中地图
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取位置
            guard let location = userLocation.location else { return }

            // 更新绑定的位置坐标
            DispatchQueue.main.async {
                self.parent.userLocation = location.coordinate
            }

            // 首次获得位置时，自动居中地图
            guard !hasInitialCentered else { return }

            // 创建居中区域（约 1 公里范围）
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )

            // 平滑居中地图
            mapView.setRegion(region, animated: true)

            // 标记已完成首次居中
            hasInitialCentered = true

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }
        }

        /// 轨迹渲染器回调（关键方法！没有这个方法轨迹不会显示！）
        /// - Parameters:
        ///   - mapView: 地图视图
        ///   - overlay: 覆盖层对象
        /// - Returns: 渲染器
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 处理轨迹线
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // 根据闭合状态设置轨迹颜色
                if isCurrentlyPathClosed {
                    renderer.strokeColor = UIColor.systemGreen  // 闭合后：绿色轨迹
                } else {
                    renderer.strokeColor = UIColor.systemCyan   // 追踪中：青色轨迹
                }

                renderer.lineWidth = 5                   // 线宽 5pt
                renderer.lineCap = .round                // 圆头线帽
                renderer.lineJoin = .round               // 圆角连接

                return renderer
            }

            // 处理多边形（领地或闭环区域）
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 根据 title 区分领地类型
                if polygon.title == "mine" {
                    // 我的领地：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                } else if polygon.title == "others" {
                    // 他人领地：橙色
                    renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemOrange
                } else {
                    // 追踪中的闭环区域：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                }

                renderer.lineWidth = 2
                return renderer
            }

            // 默认渲染器
            return MKOverlayRenderer(overlay: overlay)
        }

        /// 地图区域变化回调
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 可用于追踪用户手动拖动地图
        }

        /// 地图加载完成回调
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            // 地图瓦片加载完成
        }

        /// Day 22: POI 标记视图渲染
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 跳过用户位置标记
            if annotation is MKUserLocation {
                return nil
            }

            // 处理 POI 标记
            if let poiAnnotation = annotation as? POIAnnotation {
                let identifier = "POIAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if view == nil {
                    view = MKMarkerAnnotationView(annotation: poiAnnotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                } else {
                    view?.annotation = poiAnnotation
                }

                // 设置标记样式
                if poiAnnotation.isScavenged {
                    // 已搜刮：灰色
                    view?.markerTintColor = .systemGray
                    view?.glyphImage = UIImage(systemName: "checkmark")
                } else {
                    // 未搜刮：根据类型设置颜色
                    view?.markerTintColor = poiAnnotation.markerColor
                    view?.glyphImage = UIImage(systemName: poiAnnotation.poi.type.icon)
                }

                view?.displayPriority = .required

                return view
            }

            // Day 26: 处理建筑标记
            if let buildingAnnotation = annotation as? BuildingAnnotation {
                let identifier = "BuildingAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if view == nil {
                    view = MKMarkerAnnotationView(annotation: buildingAnnotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                } else {
                    view?.annotation = buildingAnnotation
                }

                // 设置标记样式
                view?.markerTintColor = buildingAnnotation.markerColor
                view?.glyphImage = UIImage(systemName: buildingAnnotation.iconName)
                view?.displayPriority = .required

                return view
            }

            return nil
        }
    }
}

// MARK: - POI Annotation

/// POI 标记类
class POIAnnotation: NSObject, MKAnnotation {

    /// POI 数据
    let poi: POI

    /// 标记坐标（GCJ-02）
    var coordinate: CLLocationCoordinate2D

    /// 是否已搜刮
    var isScavenged: Bool

    /// 标记标题
    var title: String? {
        poi.name
    }

    /// 标记副标题
    var subtitle: String? {
        poi.type.rawValue
    }

    /// 标记颜色
    var markerColor: UIColor {
        switch poi.type {
        case .hospital:
            return .systemRed
        case .pharmacy:
            return .systemGreen
        case .supermarket:
            return .systemBlue
        case .restaurant:
            return .systemOrange
        case .gasStation:
            return .systemYellow
        default:
            return .systemGray
        }
    }

    init(poi: POI, coordinate: CLLocationCoordinate2D, isScavenged: Bool) {
        self.poi = poi
        self.coordinate = coordinate
        self.isScavenged = isScavenged
        super.init()
    }
}

// MARK: - Building Annotation

/// 建筑标记类
class BuildingAnnotation: NSObject, MKAnnotation {

    /// 建筑数据
    let building: PlayerBuilding

    /// 建筑模板（可选）
    let template: BuildingTemplate?

    /// 标记坐标（GCJ-02）
    var coordinate: CLLocationCoordinate2D

    /// 标记标题
    var title: String? {
        building.buildingName
    }

    /// 标记副标题
    var subtitle: String? {
        building.status.displayName
    }

    /// 图标名称
    var iconName: String {
        template?.icon ?? "building.2.fill"
    }

    /// 标记颜色
    var markerColor: UIColor {
        switch building.status {
        case .constructing:
            return .systemOrange
        case .active:
            if let template = template {
                // 使用模板分类颜色
                return UIColor(template.category.color)
            }
            return .systemGreen
        case .upgrading:
            return .systemYellow
        case .damaged:
            return .systemRed
        case .inactive:
            return .systemGray
        }
    }

    init(building: PlayerBuilding, coordinate: CLLocationCoordinate2D, template: BuildingTemplate?) {
        self.building = building
        self.coordinate = coordinate
        self.template = template
        super.init()
    }
}

// MARK: - Preview

#Preview {
    MapViewRepresentable(
        userLocation: .constant(nil),
        hasLocatedUser: .constant(false),
        trackingPath: .constant([]),
        pathUpdateVersion: 0,
        isTracking: false,
        isPathClosed: false,
        territories: [],
        currentUserId: nil,
        pois: [],
        scavengedPOIIds: [],
        buildings: [],
        buildingTemplates: []
    )
}
