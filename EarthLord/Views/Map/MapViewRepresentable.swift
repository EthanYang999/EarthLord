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

            // 处理多边形（闭环区域填充）
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 半透明绿色填充
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                // 绿色边框
                renderer.strokeColor = UIColor.systemGreen
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
        isPathClosed: false
    )
}
