//
//  LocationManager.swift
//  EarthLord
//
//  GPS 定位管理器 - 处理用户位置获取、权限管理和路径追踪
//

import Foundation
import CoreLocation
import Combine

/// GPS 定位管理器
/// 负责请求定位权限、获取用户位置、处理授权状态变化、路径追踪
class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 定位错误信息
    @Published var locationError: String?

    // MARK: - 路径追踪相关属性

    /// 是否正在追踪路径
    @Published var isTracking: Bool = false

    /// 路径坐标数组（存储原始 WGS-84 坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于触发 SwiftUI 视图更新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否闭合（Day16 圈地功能会用到）
    @Published var isPathClosed: Bool = false

    // MARK: - Private Properties

    /// CoreLocation 定位管理器
    private let locationManager = CLLocationManager()

    /// 当前位置（用于 Timer 采点）
    private var currentLocation: CLLocation?

    /// 采点定时器
    private var pathUpdateTimer: Timer?

    /// 采点时间间隔（秒）
    private let pathUpdateInterval: TimeInterval = 2.0

    /// 最小采点距离（米）- 移动超过此距离才记录新点
    private let minimumDistanceForNewPoint: CLLocationDistance = 10.0

    // MARK: - Computed Properties

    /// 是否已获得定位授权
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// 是否被用户拒绝授权
    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// 是否尚未决定授权
    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    /// 路径点数量
    var pathPointCount: Int {
        pathCoordinates.count
    }

    // MARK: - Initialization

    override init() {
        // 获取当前授权状态
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 5  // 移动5米就更新位置（追踪时需要更频繁更新）
    }

    // MARK: - Public Methods

    /// 请求定位权限
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始更新位置
    func startUpdatingLocation() {
        locationError = nil
        locationManager.startUpdatingLocation()
    }

    /// 停止更新位置
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    /// 检查并请求权限，如果已授权则开始定位
    func checkAndRequestPermission() {
        switch authorizationStatus {
        case .notDetermined:
            requestPermission()
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        case .denied, .restricted:
            locationError = "定位权限被拒绝，请在设置中开启"
        @unknown default:
            break
        }
    }

    // MARK: - 路径追踪方法

    /// 开始路径追踪
    /// 启动定时器，每隔一定时间检查是否需要记录新的路径点
    func startPathTracking() {
        guard !isTracking else { return }

        // 确保定位已开启
        startUpdatingLocation()

        // 设置追踪状态
        isTracking = true
        isPathClosed = false

        // 如果有当前位置，立即记录第一个点
        if let location = currentLocation {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            print("📍 路径追踪开始，记录起点: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }

        // 启动采点定时器
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: pathUpdateInterval, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }

        print("🚶 开始路径追踪，采点间隔: \(pathUpdateInterval)秒")
    }

    /// 停止路径追踪
    /// 停止定时器，保留已记录的路径
    func stopPathTracking() {
        guard isTracking else { return }

        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 更新追踪状态
        isTracking = false

        print("⏹️ 停止路径追踪，共记录 \(pathCoordinates.count) 个点")
    }

    /// 清除路径
    /// 清空所有已记录的路径点
    func clearPath() {
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
        print("🗑️ 路径已清除")
    }

    /// 定时器回调 - 判断是否需要记录新的路径点
    private func recordPathPoint() {
        guard isTracking else { return }
        guard let location = currentLocation else {
            print("⚠️ 无法获取当前位置")
            return
        }

        // 检查是否需要记录新点（距离上一个点超过阈值）
        if let lastCoordinate = pathCoordinates.last {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let distance = location.distance(from: lastLocation)

            // 如果移动距离不够，不记录
            if distance < minimumDistanceForNewPoint {
                print("📏 移动距离 \(String(format: "%.1f", distance))m < \(Int(minimumDistanceForNewPoint))m，不记录")
                return
            }

            print("📏 移动距离 \(String(format: "%.1f", distance))m，记录新点")
        }

        // 记录新的路径点
        pathCoordinates.append(location.coordinate)
        pathUpdateVersion += 1

        print("📍 记录路径点 #\(pathCoordinates.count): \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态变化回调
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus

            // 授权后自动开始定位
            if self.isAuthorized {
                self.startUpdatingLocation()
            }
        }
    }

    /// 位置更新回调
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        DispatchQueue.main.async {
            // 更新用户位置坐标
            self.userLocation = location.coordinate

            // 关键：更新 currentLocation，供 Timer 采点使用
            self.currentLocation = location

            self.locationError = nil
        }
    }

    /// 定位失败回调
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationError = "定位权限被拒绝"
                case .locationUnknown:
                    self.locationError = "无法获取位置信息"
                case .network:
                    self.locationError = "网络错误，无法定位"
                default:
                    self.locationError = "定位失败: \(error.localizedDescription)"
                }
            } else {
                self.locationError = "定位失败: \(error.localizedDescription)"
            }
        }
    }
}
