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

    // MARK: - Singleton (Day 35)

    static let shared = LocationManager()

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

    // MARK: - 领地验证状态属性 (Day 17)

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误信息
    @Published var territoryValidationError: String? = nil

    /// 计算出的领地面积（平方米）
    @Published var calculatedArea: Double = 0

    /// 追踪开始时间（用于上传时记录）
    @Published var trackingStartTime: Date?

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

    // MARK: - 领地验证常量 (Day 17)

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 50.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 100.0

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
        print("🔔 [LocationManager] 正在请求定位权限...")
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
        print("🔍 [LocationManager] 检查定位权限状态: \(authorizationStatus.rawValue)")

        switch authorizationStatus {
        case .notDetermined:
            print("❓ [LocationManager] 权限未确定，将请求权限")
            requestPermission()
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ [LocationManager] 权限已授予，开始定位")
            startUpdatingLocation()
        case .denied, .restricted:
            print("❌ [LocationManager] 权限被拒绝或受限")
            locationError = "定位权限被拒绝，请在设置中开启"
        @unknown default:
            print("⚠️ [LocationManager] 未知的权限状态")
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
        trackingStartTime = Date()  // 记录开始时间

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

        // ⚠️ 重置所有状态（防止重复上传）
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
        trackingStartTime = nil
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
        // 重置验证状态 (Day 17)
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
        trackingStartTime = nil
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

            // Day 17: 闭环成功后自动进行领地验证
            let validationResult = validateTerritory()
            territoryValidationPassed = validationResult.isValid
            territoryValidationError = validationResult.errorMessage
        } else {
            print("🔄 闭环检测：距离起点 \(String(format: "%.1f", distanceToStart))m > \(Int(closureDistanceThreshold))m")
        }
    }

    // MARK: - 距离与面积计算 (Day 17)

    /// 计算路径总距离
    /// - Returns: 总距离（米）
    private func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var totalDistance: Double = 0

        for i in 0..<(pathCoordinates.count - 1) {
            let current = CLLocation(latitude: pathCoordinates[i].latitude,
                                    longitude: pathCoordinates[i].longitude)
            let next = CLLocation(latitude: pathCoordinates[i + 1].latitude,
                                 longitude: pathCoordinates[i + 1].longitude)
            totalDistance += current.distance(from: next)
        }

        return totalDistance
    }

    /// 使用鞋带公式计算多边形面积（考虑地球曲率）
    /// - Returns: 面积（平方米）
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        let earthRadius: Double = 6371000  // 地球半径（米）
        var area: Double = 0

        for i in 0..<pathCoordinates.count {
            let current = pathCoordinates[i]
            let next = pathCoordinates[(i + 1) % pathCoordinates.count]  // 循环取点

            // 经纬度转弧度
            let lat1 = current.latitude * .pi / 180
            let lon1 = current.longitude * .pi / 180
            let lat2 = next.latitude * .pi / 180
            let lon2 = next.longitude * .pi / 180

            // 鞋带公式（球面修正）
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        area = abs(area * earthRadius * earthRadius / 2.0)
        return area
    }

    // MARK: - 自相交检测 (Day 17)

    /// 判断两条线段是否相交（使用 CCW 算法）
    /// - Parameters:
    ///   - p1: 线段1起点
    ///   - p2: 线段1终点
    ///   - p3: 线段2起点
    ///   - p4: 线段2终点
    /// - Returns: true = 相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
                                   p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> Bool {
        /// CCW 辅助函数：判断三点是否逆时针排列
        /// 坐标映射：longitude = X轴，latitude = Y轴
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            // 叉积 = (Cy - Ay) × (Bx - Ax) - (By - Ay) × (Cx - Ax)
            let crossProduct = (C.latitude - A.latitude) * (B.longitude - A.longitude) -
                              (B.latitude - A.latitude) * (C.longitude - A.longitude)
            return crossProduct > 0
        }

        // 判断逻辑：
        // ccw(p1, p3, p4) ≠ ccw(p2, p3, p4) 且 ccw(p1, p2, p3) ≠ ccw(p1, p2, p4)
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检测整条路径是否自相交
    /// - Returns: true = 有自交
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量
        // 因为走圈回来时，首尾附近的线段物理位置很近，会被误判为相交
        let skipHeadCount = 2  // 跳过前2条线段
        let skipTailCount = 2  // 跳过后2条线段

        // 遍历每条线段 i
        for i in 0..<segmentCount {
            // ✅ 防御性索引检查
            guard i < pathSnapshot.count - 1 else {
                print("⚠️ 自交检测索引越界: i=\(i), count=\(pathSnapshot.count)")
                break
            }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            // 计算 j 的起始位置
            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            // 对比每条非相邻线段 j
            for j in startJ..<segmentCount {
                // ✅ 防御性索引检查
                guard j < pathSnapshot.count - 1 else {
                    print("⚠️ 自交检测索引越界: j=\(j), count=\(pathSnapshot.count)")
                    break
                }

                // ✅ 跳过首尾附近线段的比较（闭环时它们物理上很近，会误判）
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount
                if isHeadSegment && isTailSegment {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    // 发现自交
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交", type: .error)
                    print("❌ 自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交")
                    return true
                }
            }
        }

        TerritoryLogger.shared.log("自交检测: 无交叉 ✓", type: .info)
        print("✅ 自交检测通过")
        return false
    }

    // MARK: - 综合验证 (Day 17)

    /// 综合验证领地是否合法
    /// - Returns: (isValid: 是否通过, errorMessage: 错误信息)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始领地验证", type: .info)
        print("🔍 开始领地验证")

        // 1. 点数检查
        let pointCount = pathCoordinates.count
        if pointCount < minimumPathPoints {
            let error = "点数不足: \(pointCount)个 (需≥\(minimumPathPoints)个)"
            TerritoryLogger.shared.log("点数检查: \(error)", type: .error)
            print("❌ \(error)")
            return (false, error)
        }
        TerritoryLogger.shared.log("点数检查: \(pointCount)个点 ✓", type: .info)
        print("✅ 点数检查: \(pointCount)个点")

        // 2. 距离检查
        let totalDistance = calculateTotalPathDistance()
        if totalDistance < minimumTotalDistance {
            let error = "距离不足: \(String(format: "%.0f", totalDistance))m (需≥\(Int(minimumTotalDistance))m)"
            TerritoryLogger.shared.log("距离检查: \(error)", type: .error)
            print("❌ \(error)")
            return (false, error)
        }
        TerritoryLogger.shared.log("距离检查: \(String(format: "%.0f", totalDistance))m ✓", type: .info)
        print("✅ 距离检查: \(String(format: "%.0f", totalDistance))m")

        // 3. 自交检测
        if hasPathSelfIntersection() {
            let error = "轨迹自相交，请勿画8字形"
            TerritoryLogger.shared.log("验证失败: \(error)", type: .error)
            print("❌ \(error)")
            return (false, error)
        }

        // 4. 面积检查
        let area = calculatePolygonArea()
        calculatedArea = area  // 保存计算结果
        if area < minimumEnclosedArea {
            let error = "面积不足: \(String(format: "%.0f", area))m² (需≥\(Int(minimumEnclosedArea))m²)"
            TerritoryLogger.shared.log("面积检查: \(error)", type: .error)
            print("❌ \(error)")
            return (false, error)
        }
        TerritoryLogger.shared.log("面积检查: \(String(format: "%.0f", area))m² ✓", type: .info)
        print("✅ 面积检查: \(String(format: "%.0f", area))m²")

        // 验证通过
        TerritoryLogger.shared.log("领地验证通过！面积: \(String(format: "%.0f", area))m²", type: .success)
        print("🎉 领地验证通过！面积: \(String(format: "%.0f", area))m²")
        return (true, nil)
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

            // 调试日志
            print("📍 [LocationManager] 位置更新成功: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            print("📍 [LocationManager] 精度: \(location.horizontalAccuracy)m")
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
