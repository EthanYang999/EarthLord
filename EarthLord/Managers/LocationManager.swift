//
//  LocationManager.swift
//  EarthLord
//
//  GPS 定位管理器 - 处理用户位置获取和权限管理
//

import Foundation
import CoreLocation
import Combine

/// GPS 定位管理器
/// 负责请求定位权限、获取用户位置、处理授权状态变化
class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 定位错误信息
    @Published var locationError: String?

    // MARK: - Private Properties

    /// CoreLocation 定位管理器
    private let locationManager = CLLocationManager()

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

    // MARK: - Initialization

    override init() {
        // 获取当前授权状态
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 10  // 移动10米才更新位置
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
            self.userLocation = location.coordinate
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
