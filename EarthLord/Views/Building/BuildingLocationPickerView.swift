//
//  BuildingLocationPickerView.swift
//  EarthLord
//
//  建筑位置选择器
//  使用 UIKit MKMapView 显示领地多边形边界和已有建筑，让玩家选择建筑位置
//

import SwiftUI
import MapKit

/// 建筑位置选择器
struct BuildingLocationPickerView: View {
    // MARK: - Properties

    /// 领地边界坐标点（多边形）
    let territoryCoordinates: [CLLocationCoordinate2D]

    /// 已有建筑列表
    let existingBuildings: [PlayerBuilding]

    /// 建筑模板字典
    let buildingTemplates: [String: BuildingTemplate]

    /// 选择位置回调
    let onSelectLocation: (CLLocationCoordinate2D) -> Void

    /// 取消回调
    let onCancel: () -> Void

    // MARK: - State

    /// 选中的坐标
    @State private var selectedCoordinate: CLLocationCoordinate2D?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 地图视图（UIKit）
                LocationPickerMapView(
                    territoryCoordinates: territoryCoordinates,
                    existingBuildings: existingBuildings,
                    buildingTemplates: buildingTemplates,
                    selectedCoordinate: $selectedCoordinate
                )
                .ignoresSafeArea(edges: .bottom)

                // 底部信息栏
                VStack {
                    Spacer()
                    bottomInfoBar
                }
            }
            .navigationTitle("选择位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        if let coord = selectedCoordinate {
                            onSelectLocation(coord)
                        }
                    }
                    .disabled(selectedCoordinate == nil)
                }
            }
        }
    }

    // MARK: - Subviews

    /// 底部信息栏
    private var bottomInfoBar: some View {
        VStack(spacing: 8) {
            if let coord = selectedCoordinate {
                // 已选择位置
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.success)
                    Text("已选择位置")
                        .fontWeight(.medium)
                    Spacer()
                }

                HStack {
                    Text("坐标:")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text(String(format: "%.5f, %.5f", coord.latitude, coord.longitude))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                }
            } else {
                // 未选择
                HStack {
                    Image(systemName: "hand.tap")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("点击地图选择建筑位置")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12))
    }
}

// MARK: - UIKit Map View

/// UIKit 地图视图包装器
struct LocationPickerMapView: UIViewRepresentable {
    let territoryCoordinates: [CLLocationCoordinate2D]
    let existingBuildings: [PlayerBuilding]
    let buildingTemplates: [String: BuildingTemplate]
    @Binding var selectedCoordinate: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .hybrid

        // 添加领地多边形
        if territoryCoordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: territoryCoordinates, count: territoryCoordinates.count)
            mapView.addOverlay(polygon)

            // 设置地图区域为领地范围
            let region = regionForPolygon(territoryCoordinates)
            mapView.setRegion(region, animated: false)
        }

        // 添加已有建筑标记
        context.coordinator.addExistingBuildings(to: mapView)

        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新选中位置标注（保留已有建筑标记）
        let selectedAnnotations = mapView.annotations.filter {
            guard let pointAnnotation = $0 as? MKPointAnnotation else { return false }
            return pointAnnotation.title == "建筑位置"
        }
        mapView.removeAnnotations(selectedAnnotations)

        if let coord = selectedCoordinate {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coord
            annotation.title = "建筑位置"
            mapView.addAnnotation(annotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// 计算多边形的区域
    private func regionForPolygon(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5,
            longitudeDelta: (maxLon - minLon) * 1.5
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LocationPickerMapView

        init(_ parent: LocationPickerMapView) {
            self.parent = parent
        }

        /// 添加已有建筑到地图
        func addExistingBuildings(to mapView: MKMapView) {
            for building in parent.existingBuildings {
                guard let coord = building.coordinate else { continue }

                // 数据库中的坐标已经是 GCJ-02，直接使用
                let annotation = ExistingBuildingAnnotation(
                    building: building,
                    template: parent.buildingTemplates[building.templateId]
                )
                annotation.coordinate = coord
                mapView.addAnnotation(annotation)
            }
        }

        /// 处理地图点击
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }

            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            // 检查是否在多边形内
            if isPointInPolygon(coordinate, polygon: parent.territoryCoordinates) {
                parent.selectedCoordinate = coordinate
            }
        }

        /// 射线法判断点是否在多边形内
        private func isPointInPolygon(_ point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
            guard polygon.count >= 3 else { return false }

            var isInside = false
            var j = polygon.count - 1

            for i in 0..<polygon.count {
                let xi = polygon[i].longitude
                let yi = polygon[i].latitude
                let xj = polygon[j].longitude
                let yj = polygon[j].latitude

                if ((yi > point.latitude) != (yj > point.latitude)) &&
                   (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi) {
                    isInside = !isInside
                }
                j = i
            }

            return isInside
        }

        /// 渲染多边形覆盖层
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

        /// 自定义标注视图
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            // 已有建筑标记
            if let buildingAnnotation = annotation as? ExistingBuildingAnnotation {
                let identifier = "ExistingBuilding"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }

                // 创建建筑图标
                annotationView?.image = createBuildingIcon(
                    building: buildingAnnotation.building,
                    template: buildingAnnotation.template
                )
                annotationView?.frame.size = CGSize(width: 50, height: 60)
                annotationView?.centerOffset = CGPoint(x: 0, y: -30)

                return annotationView
            }

            // 选中位置标记
            let identifier = "BuildingLocation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            annotationView?.markerTintColor = .systemOrange
            annotationView?.glyphImage = UIImage(systemName: "building.2.fill")

            return annotationView
        }

        /// 创建建筑图标
        private func createBuildingIcon(building: PlayerBuilding, template: BuildingTemplate?) -> UIImage {
            let size = CGSize(width: 50, height: 60)
            let renderer = UIGraphicsImageRenderer(size: size)

            return renderer.image { context in
                // 圆形背景
                let iconRect = CGRect(x: 5, y: 5, width: 40, height: 40)
                let circlePath = UIBezierPath(ovalIn: iconRect)

                // 背景颜色（根据分类）
                let bgColor = getCategoryColor(template: template)
                bgColor.withAlphaComponent(0.9).setFill()
                circlePath.fill()

                // 边框
                UIColor.white.setStroke()
                circlePath.lineWidth = 2
                circlePath.stroke()

                // 系统图标
                let iconName = template?.icon ?? "building.2.fill"
                let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
                if let icon = UIImage(systemName: iconName, withConfiguration: config) {
                    let tintedIcon = icon.withTintColor(.white, renderingMode: .alwaysOriginal)
                    let iconImageRect = CGRect(x: 15, y: 15, width: 20, height: 20)
                    tintedIcon.draw(in: iconImageRect)
                }

                // 等级标签
                let levelText = "Lv.\(building.level)"
                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let textSize = levelText.size(withAttributes: textAttributes)
                let textRect = CGRect(
                    x: (size.width - textSize.width) / 2,
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
    }
}

// MARK: - Existing Building Annotation

/// 已有建筑标记
class ExistingBuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding
    let template: BuildingTemplate?
    dynamic var coordinate: CLLocationCoordinate2D

    var title: String? { building.buildingName }
    var subtitle: String? { "Lv.\(building.level)" }

    init(building: PlayerBuilding, template: BuildingTemplate?) {
        self.building = building
        self.template = template
        self.coordinate = building.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        super.init()
    }
}

#Preview {
    BuildingLocationPickerView(
        territoryCoordinates: [
            CLLocationCoordinate2D(latitude: 31.230, longitude: 121.470),
            CLLocationCoordinate2D(latitude: 31.230, longitude: 121.475),
            CLLocationCoordinate2D(latitude: 31.235, longitude: 121.475),
            CLLocationCoordinate2D(latitude: 31.235, longitude: 121.470)
        ],
        existingBuildings: [],
        buildingTemplates: [:],
        onSelectLocation: { _ in },
        onCancel: {}
    )
}
