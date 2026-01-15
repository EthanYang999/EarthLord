//
//  TerritoryMapView.swift
//  EarthLord
//
//  领地详情页地图视图（UIKit MKMapView）
//  显示领地多边形和建筑标记，支持建造进度实时更新
//

import SwiftUI
import MapKit

/// 领地地图视图
struct TerritoryMapView: UIViewRepresentable {

    // MARK: - Properties

    /// 领地边界坐标（GCJ-02）
    let territoryCoordinates: [CLLocationCoordinate2D]

    /// 建筑列表
    let buildings: [PlayerBuilding]

    /// 建筑模板字典
    let templates: [String: BuildingTemplate]

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        // 地图样式
        mapView.mapType = .hybrid
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = false
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.showsCompass = true

        // 添加领地多边形
        addTerritoryPolygon(to: mapView)

        // 设置初始区域
        setInitialRegion(mapView: mapView)

        // 添加建筑标记
        context.coordinator.updateBuildings(mapView: mapView, buildings: buildings, templates: templates)

        // 启动进度刷新定时器
        context.coordinator.startRefreshTimer(mapView: mapView)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新建筑标记
        context.coordinator.updateBuildings(mapView: mapView, buildings: buildings, templates: templates)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Private Methods

    /// 添加领地多边形
    private func addTerritoryPolygon(to mapView: MKMapView) {
        guard territoryCoordinates.count >= 3 else { return }

        let polygon = MKPolygon(coordinates: territoryCoordinates, count: territoryCoordinates.count)
        polygon.title = "territory"
        mapView.addOverlay(polygon)
    }

    /// 设置初始地图区域
    private func setInitialRegion(mapView: MKMapView) {
        guard !territoryCoordinates.isEmpty else { return }

        // 计算中心点
        let latSum = territoryCoordinates.reduce(0) { $0 + $1.latitude }
        let lonSum = territoryCoordinates.reduce(0) { $0 + $1.longitude }
        let center = CLLocationCoordinate2D(
            latitude: latSum / Double(territoryCoordinates.count),
            longitude: lonSum / Double(territoryCoordinates.count)
        )

        // 计算合适的缩放级别
        var minLat = territoryCoordinates[0].latitude
        var maxLat = territoryCoordinates[0].latitude
        var minLon = territoryCoordinates[0].longitude
        var maxLon = territoryCoordinates[0].longitude

        for coord in territoryCoordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5 + 0.002,
            longitudeDelta: (maxLon - minLon) * 1.5 + 0.002
        )

        let region = MKCoordinateRegion(center: center, span: span)
        mapView.setRegion(region, animated: false)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TerritoryMapView

        /// 建筑标记缓存
        private var buildingAnnotations: [UUID: MKPointAnnotation] = [:]

        /// 缓存的建筑数据
        private var cachedBuildings: [PlayerBuilding] = []

        /// 缓存的模板数据
        private var cachedTemplates: [String: BuildingTemplate] = [:]

        /// 进度刷新定时器
        private var refreshTimer: Timer?

        /// 地图视图引用（用于定时器刷新）
        private weak var mapViewRef: MKMapView?

        init(_ parent: TerritoryMapView) {
            self.parent = parent
            super.init()
        }

        deinit {
            refreshTimer?.invalidate()
        }

        // MARK: - Timer

        /// 启动进度刷新定时器
        func startRefreshTimer(mapView: MKMapView) {
            mapViewRef = mapView
            refreshTimer?.invalidate()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.refreshBuildingProgress()
            }
        }

        /// 刷新建造中建筑的进度
        private func refreshBuildingProgress() {
            guard let mapView = mapViewRef else { return }

            // 检查是否有建造中的建筑
            let constructingBuildings = cachedBuildings.filter { $0.status == .constructing || $0.status == .upgrading }
            guard !constructingBuildings.isEmpty else { return }

            // 刷新这些建筑的 AnnotationView
            for building in constructingBuildings {
                if let annotation = buildingAnnotations[building.id],
                   let view = mapView.view(for: annotation) {
                    // 强制重新创建视图来更新进度
                    view.setNeedsDisplay()
                }
            }

            // 通过移除并重新添加来强制刷新
            let annotationsToRefresh = constructingBuildings.compactMap { buildingAnnotations[$0.id] }
            if !annotationsToRefresh.isEmpty {
                mapView.removeAnnotations(annotationsToRefresh)
                mapView.addAnnotations(annotationsToRefresh)
            }
        }

        // MARK: - Building Management

        /// 更新建筑标记
        func updateBuildings(mapView: MKMapView, buildings: [PlayerBuilding], templates: [String: BuildingTemplate]) {
            // 缓存数据
            cachedBuildings = buildings
            cachedTemplates = templates

            let currentIds = Set(buildings.map { $0.id })

            // 移除不存在的建筑标记
            let removedIds = buildingAnnotations.keys.filter { !currentIds.contains($0) }
            for id in removedIds {
                if let annotation = buildingAnnotations[id] {
                    mapView.removeAnnotation(annotation)
                    buildingAnnotations.removeValue(forKey: id)
                }
            }

            // 添加或更新建筑标记
            for building in buildings {
                guard let coord = building.coordinate else { continue }

                // 注意：数据库中保存的已经是 GCJ-02 坐标，直接使用无需转换

                if let existingAnnotation = buildingAnnotations[building.id] {
                    // 更新现有标记
                    existingAnnotation.coordinate = coord
                    existingAnnotation.subtitle = "Lv.\(building.level) - \(building.status.displayName)"
                } else {
                    // 创建新标记
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = coord
                    annotation.title = building.buildingName
                    annotation.subtitle = "Lv.\(building.level) - \(building.status.displayName)"

                    buildingAnnotations[building.id] = annotation
                    mapView.addAnnotation(annotation)
                }
            }
        }

        // MARK: - MKMapViewDelegate

        /// 渲染多边形
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 3.0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        /// 渲染建筑标记
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 跳过用户位置
            if annotation is MKUserLocation { return nil }

            guard let pointAnnotation = annotation as? MKPointAnnotation,
                  let buildingTitle = pointAnnotation.title else { return nil }

            let identifier = "BuildingAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            // 查找对应的建筑
            if let building = cachedBuildings.first(where: { $0.buildingName == buildingTitle }) {
                let template = cachedTemplates[building.templateId]
                annotationView?.image = createBuildingIcon(building: building, template: template)
                annotationView?.frame.size = CGSize(width: 60, height: 70)
                annotationView?.centerOffset = CGPoint(x: 0, y: -35)
                annotationView?.layer.zPosition = 1000
                annotationView?.displayPriority = .required
            } else {
                // 默认图标
                annotationView?.image = UIImage(systemName: "building.2.fill")?
                    .withTintColor(.systemOrange, renderingMode: .alwaysOriginal)
            }

            return annotationView
        }

        // MARK: - Icon Creation

        /// 创建建筑图标
        private func createBuildingIcon(building: PlayerBuilding, template: BuildingTemplate?) -> UIImage {
            let size = CGSize(width: 60, height: 70)
            let renderer = UIGraphicsImageRenderer(size: size)

            return renderer.image { context in
                // 1. 圆形背景
                let iconRect = CGRect(x: 5, y: 5, width: 50, height: 50)
                let circlePath = UIBezierPath(ovalIn: iconRect)

                // 背景颜色（根据分类）
                let bgColor = getCategoryColor(template: template)
                bgColor.withAlphaComponent(0.9).setFill()
                circlePath.fill()

                // 边框颜色（根据状态）
                let borderColor = getStatusColor(status: building.status)
                borderColor.setStroke()
                circlePath.lineWidth = 3
                circlePath.stroke()

                // 2. 系统图标
                let iconName = template?.icon ?? "building.2.fill"
                let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
                if let icon = UIImage(systemName: iconName, withConfiguration: config) {
                    let tintedIcon = icon.withTintColor(.white, renderingMode: .alwaysOriginal)
                    let iconImageRect = CGRect(x: 18, y: 18, width: 24, height: 24)
                    tintedIcon.draw(in: iconImageRect)
                }

                // 3. 进度条（建造中或升级中）
                if building.status == .constructing || building.status == .upgrading {
                    let progressBarRect = CGRect(x: 5, y: 58, width: 50, height: 6)

                    // 背景
                    UIColor(white: 0.3, alpha: 0.8).setFill()
                    UIBezierPath(roundedRect: progressBarRect, cornerRadius: 3).fill()

                    // 进度
                    let progress = CGFloat(building.buildProgress)
                    let progressRect = CGRect(
                        x: progressBarRect.minX,
                        y: progressBarRect.minY,
                        width: progressBarRect.width * progress,
                        height: progressBarRect.height
                    )

                    let progressColor = building.status == .constructing ?
                        UIColor.systemOrange : UIColor.systemBlue
                    progressColor.setFill()
                    UIBezierPath(roundedRect: progressRect, cornerRadius: 3).fill()
                }

                // 4. 等级标签
                let levelText = "Lv.\(building.level)"
                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let textSize = levelText.size(withAttributes: textAttributes)
                let textRect = CGRect(
                    x: size.width - textSize.width - 5,
                    y: size.height - textSize.height - 2,
                    width: textSize.width,
                    height: textSize.height
                )

                // 文字背景
                UIColor(white: 0, alpha: 0.7).setFill()
                UIBezierPath(roundedRect: textRect.insetBy(dx: -3, dy: -1), cornerRadius: 3).fill()

                // 绘制文字
                levelText.draw(in: textRect, withAttributes: textAttributes)
            }
        }

        /// 获取分类颜色
        private func getCategoryColor(template: BuildingTemplate?) -> UIColor {
            guard let template = template else { return UIColor.systemGray }

            switch template.category {
            case .survival:
                return UIColor.systemOrange
            case .storage:
                return UIColor.systemBrown
            case .production:
                return UIColor.systemGreen
            case .energy:
                return UIColor.systemYellow
            }
        }

        /// 获取状态颜色
        private func getStatusColor(status: BuildingStatus) -> UIColor {
            switch status {
            case .constructing:
                return UIColor.systemOrange
            case .active:
                return UIColor.systemGreen
            case .upgrading:
                return UIColor.systemBlue
            case .damaged:
                return UIColor.systemRed
            case .inactive:
                return UIColor.systemGray
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TerritoryMapView(
        territoryCoordinates: [
            CLLocationCoordinate2D(latitude: 31.230, longitude: 121.470),
            CLLocationCoordinate2D(latitude: 31.230, longitude: 121.475),
            CLLocationCoordinate2D(latitude: 31.235, longitude: 121.475),
            CLLocationCoordinate2D(latitude: 31.235, longitude: 121.470)
        ],
        buildings: [],
        templates: [:]
    )
}
