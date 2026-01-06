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

    /// 路径是否闭合
    @Published var isPathClosed: Bool = false

    // MARK: - 速度检测属性 (Day 16)

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

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

    /// 闭环距离阈值（米）- 距离起点小于此值视为闭环
    private let closureDistanceThreshold: Double = 30.0

    /// 最少路径点数 - 至少需要这么多点才能形成闭环
    private let minimumPathPoints: Int = 10

    /// 上次位置时间戳（用于速度计算）
    private var lastLocationTimestamp: Date?

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

        // 重置速度检测状态
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil

        // 如果有当前位置，立即记录第一个点
        if let location = currentLocation {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            lastLocationTimestamp = location.timestamp  // 记录起点时间戳
            print("📍 路径追踪开始，记录起点: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }

        // 启动采点定时器
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: pathUpdateInterval, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }

        print("🚶 开始路径追踪，采点间隔: \(pathUpdateInterval)秒")

        // 添加日志
        TerritoryLogger.shared.log("开始圈地追踪", type: .info)
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

        // 添加日志
        TerritoryLogger.shared.log("停止追踪，共 \(pathCoordinates.count) 个点", type: .info)
    }

    /// 清除路径
    /// 清空所有已记录的路径点
    func clearPath() {
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil
        print("🗑️ 路径已清除")
    }

    /// 定时器回调 - 记录路径点
    /// ⚠️ 关键：先检查距离，再检查速度！顺序不能反！
    private func recordPathPoint() {
        guard isTracking else { return }
        guard !isPathClosed else {
            print("🔒 路径已闭环，停止记录")
            return
        }
        guard let location = currentLocation else {
            print("⚠️ 无法获取当前位置")
            return
        }

        // 步骤1：先检查距离（过滤 GPS 漂移，距离不够就直接返回）
        if let lastCoordinate = pathCoordinates.last {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let distance = location.distance(from: lastLocation)

            // 如果移动距离不够，不记录，也不进行速度检测
            guard distance >= minimumDistanceForNewPoint else {
                print("📏 移动距离 \(String(format: "%.1f", distance))m < \(Int(minimumDistanceForNewPoint))m，不记录")
                return
            }

            print("📏 移动距离 \(String(format: "%.1f", distance))m，准备记录")
        }

        // 步骤2：再检查速度（只对真实移动进行检测）
        guard validateMovementSpeed(newLocation: location) else {
            print("🚨 严重超速，不记录该点")
            return
        }

        // 步骤3：记录新点
        pathCoordinates.append(location.coordinate)
        pathUpdateVersion += 1

        // 计算距上一点的距离（用于日志）
        var distanceFromLast: Double = 0
        if pathCoordinates.count >= 2 {
            let prevCoord = pathCoordinates[pathCoordinates.count - 2]
            let prevLocation = CLLocation(latitude: prevCoord.latitude, longitude: prevCoord.longitude)
            distanceFromLast = location.distance(from: prevLocation)
        }

        print("📍 记录路径点 #\(pathCoordinates.count): \(location.coordinate.latitude), \(location.coordinate.longitude)")

        // 添加日志
        TerritoryLogger.shared.log("记录第 \(pathCoordinates.count) 个点，距上点 \(String(format: "%.1f", distanceFromLast))m", type: .info)

        // 步骤4：检测闭环
        checkPathClosure()
    }

    // MARK: - 闭环检测 (Day 16)

    /// 检查路径是否形成闭环
    /// 当路径点数 ≥ 10 且当前位置距离起点 ≤ 30 米时，判定为闭环
    private func checkPathClosure() {
        // 已经闭环则不再检测
        guard !isPathClosed else { return }

        // 检查点数是否足够
        guard pathCoordinates.count >= minimumPathPoints else {
            print("🔄 闭环检测：点数不足（\(pathCoordinates.count)/\(minimumPathPoints)）")
            return
        }

        // 获取起点和当前点
        guard let startCoordinate = pathCoordinates.first,
              let currentCoordinate = pathCoordinates.last else { return }

        // 计算当前位置到起点的距离
        let startLocation = CLLocation(latitude: startCoordinate.latitude, longitude: startCoordinate.longitude)
        let currentLocation = CLLocation(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)
        let distanceToStart = currentLocation.distance(from: startLocation)

        // 添加日志（点数够了，显示距起点距离）
        TerritoryLogger.shared.log("距起点 \(String(format: "%.1f", distanceToStart))m (需≤30m)", type: .info)

        // 判断是否闭环
        if distanceToStart <= closureDistanceThreshold {
            isPathClosed = true
            pathUpdateVersion += 1  // 触发视图更新以显示多边形
            print("✅ 闭环检测成功！距离起点 \(String(format: "%.1f", distanceToStart))m ≤ \(Int(closureDistanceThreshold))m")

            // 添加成功日志
            TerritoryLogger.shared.log("闭环成功！距起点 \(String(format: "%.1f", distanceToStart))m", type: .success)
        } else {
            print("🔄 闭环检测：距离起点 \(String(format: "%.1f", distanceToStart))m > \(Int(closureDistanceThreshold))m")
        }
    }

    // MARK: - 速度检测 (Day 16)

    /// 验证移动速度是否正常
    /// - Parameter newLocation: 新的位置
    /// - Returns: true 表示可以记录该点，false 表示严重超速不记录
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 获取上一个位置
        guard let lastCoordinate = pathCoordinates.last else {
            // 第一个点，记录时间戳并返回正常
            lastLocationTimestamp = newLocation.timestamp
            return true
        }

        // 获取上次时间戳
        guard let lastTimestamp = lastLocationTimestamp else {
            lastLocationTimestamp = newLocation.timestamp
            return true
        }

        // 计算距离（米）
        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = newLocation.distance(from: lastLocation)

        // 计算时间差（秒）
        let timeDiff = newLocation.timestamp.timeIntervalSince(lastTimestamp)

        // 避免除以零
        guard timeDiff > 0 else { return true }

        // 计算速度（km/h）
        let speedMPS = distance / timeDiff  // 米/秒
        let speedKMH = speedMPS * 3.6       // 转换为 km/h

        print("🚗 速度检测：\(String(format: "%.1f", speedKMH)) km/h（移动 \(String(format: "%.1f", distance))m，用时 \(String(format: "%.1f", timeDiff))s）")

        // 更新时间戳
        lastLocationTimestamp = newLocation.timestamp

        // 速度检测
        if speedKMH > 30 {
            // 严重超速（>30 km/h）：停止追踪
            speedWarning = "速度过快（\(String(format: "%.0f", speedKMH)) km/h），已暂停追踪"
            isOverSpeed = true
            stopPathTracking()
            print("🚨 严重超速！速度 \(String(format: "%.1f", speedKMH)) km/h > 30 km/h，自动停止追踪")

            // 添加错误日志
            TerritoryLogger.shared.log("超速 \(String(format: "%.0f", speedKMH)) km/h，已停止追踪", type: .error)
            return false
        } else if speedKMH > 15 {
            // 轻度超速（>15 km/h）：警告但继续记录
            speedWarning = "移动速度过快（\(String(format: "%.0f", speedKMH)) km/h），请慢行"
            isOverSpeed = true
            print("⚠️ 超速警告！速度 \(String(format: "%.1f", speedKMH)) km/h > 15 km/h，继续记录")

            // 添加警告日志
            TerritoryLogger.shared.log("速度较快 \(String(format: "%.0f", speedKMH)) km/h", type: .warning)
            return true  // 警告但继续记录
        } else {
            // 速度正常
            if isOverSpeed {
                speedWarning = nil
                isOverSpeed = false
            }
            return true
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
