//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView 的 SwiftUI 包装器 - 显示末世风格地图
//

import SwiftUI
import MapKit

/// MKMapView 的 SwiftUI 包装器
/// 显示卫星混合地图，应用末世滤镜效果，处理用户位置显示和地图居中
struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - Bindings

    /// 用户位置坐标（双向绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位（防止重复居中）
    @Binding var hasLocatedUser: Bool

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

        // 设置代理（关键！否则 didUpdate userLocation 不会被调用）
        mapView.delegate = context.coordinator

        // 应用末世滤镜效果
        applyApocalypseFilter(to: mapView)

        return mapView
    }

    /// 更新 MKMapView（SwiftUI 状态变化时调用）
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 空实现：地图居中由 Coordinator 的 delegate 方法处理
    }

    /// 创建 Coordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Private Methods

    /// 应用末世滤镜效果
    /// 降低饱和度 + 添加棕褐色调，营造废土氛围
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 色调控制：降低饱和度和亮度
        guard let colorControls = CIFilter(name: "CIColorControls") else { return }
        colorControls.setValue(-0.15, forKey: kCIInputBrightnessKey)  // 稍微变暗
        colorControls.setValue(0.5, forKey: kCIInputSaturationKey)    // 降低饱和度

        // 棕褐色调：废土的泛黄效果
        guard let sepiaFilter = CIFilter(name: "CISepiaTone") else { return }
        sepiaFilter.setValue(0.65, forKey: kCIInputIntensityKey)

        // 应用到地图图层
        mapView.layer.filters = [colorControls, sepiaFilter]
    }

    // MARK: - Coordinator

    /// Coordinator 类 - 处理 MKMapView 的代理回调
    class Coordinator: NSObject, MKMapViewDelegate {

        /// 父视图引用
        var parent: MapViewRepresentable

        /// 是否已完成首次居中（防止重复居中）
        private var hasInitialCentered = false

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
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
