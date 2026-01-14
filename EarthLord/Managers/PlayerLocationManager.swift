//
//  PlayerLocationManager.swift
//  EarthLord
//
//  玩家位置管理器
//  负责位置上报、附近玩家查询、在线状态管理
//

import Foundation
import CoreLocation
import Combine
import UIKit
import Supabase

// MARK: - 密度等级枚举

/// 玩家密度等级
/// 根据附近玩家数量决定 POI 显示策略
enum PlayerDensityLevel: String {
    case solo = "独行者"       // 0 人
    case low = "低密度"        // 1-5 人
    case medium = "中密度"     // 6-20 人
    case high = "高密度"       // 20+ 人

    /// 推荐的 POI 显示数量
    var recommendedPOICount: Int {
        switch self {
        case .solo: return 1      // 保底显示 1 个
        case .low: return 3       // 显示 2-3 个
        case .medium: return 6    // 显示 4-6 个
        case .high: return 20     // 显示所有（最多 20）
        }
    }

    /// 根据玩家数量确定密度等级
    static func from(playerCount: Int) -> PlayerDensityLevel {
        switch playerCount {
        case 0: return .solo
        case 1...5: return .low
        case 6...20: return .medium
        default: return .high
        }
    }
}

// MARK: - RPC 参数结构体（使用 @unchecked Sendable 绕过 MainActor 隔离）

/// 位置上报参数
private struct LocationReportParams: Encodable, @unchecked Sendable {
    nonisolated let pLatitude: Double
    nonisolated let pLongitude: Double

    nonisolated enum CodingKeys: String, CodingKey {
        case pLatitude = "p_latitude"
        case pLongitude = "p_longitude"
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pLatitude, forKey: .pLatitude)
        try container.encode(pLongitude, forKey: .pLongitude)
    }
}

/// 附近玩家查询参数
private struct NearbyQueryParams: Encodable, @unchecked Sendable {
    nonisolated let pLatitude: Double
    nonisolated let pLongitude: Double
    nonisolated let pRadiusMeters: Int

    nonisolated enum CodingKeys: String, CodingKey {
        case pLatitude = "p_latitude"
        case pLongitude = "p_longitude"
        case pRadiusMeters = "p_radius_meters"
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pLatitude, forKey: .pLatitude)
        try container.encode(pLongitude, forKey: .pLongitude)
        try container.encode(pRadiusMeters, forKey: .pRadiusMeters)
    }
}

// MARK: - PlayerLocationManager

/// 玩家位置管理器
/// 负责上报玩家位置、查询附近玩家数量
@MainActor
final class PlayerLocationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = PlayerLocationManager()

    // MARK: - Published Properties

    /// 附近玩家数量
    @Published private(set) var nearbyPlayerCount: Int = 0

    /// 当前密度等级
    @Published private(set) var densityLevel: PlayerDensityLevel = .solo

    /// 是否正在上报位置
    @Published private(set) var isReporting: Bool = false

    /// 上次上报时间
    @Published private(set) var lastReportTime: Date?

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Constants

    /// 定时上报间隔（秒）
    private let reportInterval: TimeInterval = 30.0

    /// 距离触发阈值（米）- 移动超过此距离立即上报
    private let distanceThreshold: CLLocationDistance = 50.0

    /// 查询半径（米）
    private let queryRadius: Int = 1000

    // MARK: - Private Properties

    /// 位置更新订阅
    private var locationSubscription: AnyCancellable?

    /// 定时上报定时器
    private var reportTimer: Timer?

    /// 上次上报的位置
    private var lastReportedLocation: CLLocationCoordinate2D?

    /// 是否已激活（正在探索中）
    private var isActive: Bool = false

    /// App 进入后台观察者
    private var backgroundObserver: NSObjectProtocol?

    /// App 进入前台观察者
    private var foregroundObserver: NSObjectProtocol?

    // MARK: - Initialization

    private init() {
        setupAppLifecycleObservers()
    }

    deinit {
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - App 生命周期管理

    /// 设置 App 生命周期观察者
    private func setupAppLifecycleObservers() {
        // 进入后台时标记离线
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.markOffline()
            }
        }

        // 进入前台时恢复上报
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                guard strongSelf.isActive else { return }
                strongSelf.startReportTimer()
            }
        }
    }

    // MARK: - Public Methods

    /// 激活位置上报（探索开始时调用）
    /// - Parameter locationManager: 位置管理器
    func activate(with locationManager: LocationManager) {
        guard !isActive else {
            print("[PlayerLocationManager] 已激活，跳过")
            return
        }

        // 检查用户登录状态
        Task {
            guard let _ = try? await supabase.auth.session.user.id else {
                print("[PlayerLocationManager] 用户未登录，跳过位置上报")
                return
            }

            isActive = true
            print("[PlayerLocationManager] 激活位置上报")

            // 订阅位置更新
            locationSubscription = locationManager.$userLocation
                .compactMap { $0 }
                .sink { [weak self] coordinate in
                    self?.handleLocationUpdate(coordinate)
                }

            // 立即上报当前位置
            if let location = locationManager.userLocation {
                await self.reportLocation(location)
            }

            // 启动定时上报
            startReportTimer()
        }
    }

    /// 停用位置上报（探索结束时调用）
    func deactivate() {
        guard isActive else { return }

        isActive = false
        print("[PlayerLocationManager] 停用位置上报")

        // 停止订阅
        locationSubscription?.cancel()
        locationSubscription = nil

        // 停止定时器
        stopReportTimer()

        // 标记离线
        Task {
            await self.markOffline()
        }

        // 重置状态
        nearbyPlayerCount = 0
        densityLevel = .solo
        lastReportedLocation = nil
    }

    /// 查询附近玩家数量
    /// - Parameter location: 查询中心点
    /// - Returns: 附近玩家数量
    func queryNearbyPlayers(at location: CLLocationCoordinate2D) async -> Int {
        do {
            let count = try await performNearbyQuery(
                latitude: location.latitude,
                longitude: location.longitude,
                radius: queryRadius
            )

            // 更新状态
            nearbyPlayerCount = count
            densityLevel = PlayerDensityLevel.from(playerCount: count)

            print("[PlayerLocationManager] 附近玩家: \(count) 人，密度: \(densityLevel.rawValue)")

            return count

        } catch {
            print("[PlayerLocationManager] 查询附近玩家失败: \(error)")
            errorMessage = "查询附近玩家失败"
            return 0
        }
    }

    /// 执行附近玩家查询（nonisolated 避免 Sendable 问题）
    nonisolated private func performNearbyQuery(latitude: Double, longitude: Double, radius: Int) async throws -> Int {
        let params = NearbyQueryParams(
            pLatitude: latitude,
            pLongitude: longitude,
            pRadiusMeters: radius
        )

        let count: Int = try await supabase
            .rpc("count_nearby_players", params: params)
            .execute()
            .value

        return count
    }

    /// 获取推荐的 POI 数量
    /// - Parameter playerCount: 附近玩家数量
    /// - Returns: 推荐显示的 POI 数量
    func getRecommendedPOICount(for playerCount: Int) -> Int {
        return PlayerDensityLevel.from(playerCount: playerCount).recommendedPOICount
    }

    // MARK: - Private Methods

    /// 处理位置更新
    private func handleLocationUpdate(_ coordinate: CLLocationCoordinate2D) {
        // 检查是否需要立即上报（移动超过 50 米）
        if let lastLocation = lastReportedLocation {
            let currentLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let lastLoc = CLLocation(latitude: lastLocation.latitude, longitude: lastLocation.longitude)
            let distance = currentLoc.distance(from: lastLoc)

            if distance >= distanceThreshold {
                print("[PlayerLocationManager] 移动 \(String(format: "%.0f", distance))m，触发即时上报")
                Task {
                    await self.reportLocation(coordinate)
                }
            }
        }
    }

    /// 上报位置到服务器
    private func reportLocation(_ coordinate: CLLocationCoordinate2D) async {
        guard !isReporting else { return }

        isReporting = true
        defer { isReporting = false }

        do {
            try await performLocationReport(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )

            // 更新状态
            lastReportedLocation = coordinate
            lastReportTime = Date()

            print("[PlayerLocationManager] 位置上报成功: \(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude))")

        } catch {
            print("[PlayerLocationManager] 位置上报失败: \(error)")
            errorMessage = "位置上报失败"
        }
    }

    /// 执行位置上报（nonisolated 避免 Sendable 问题）
    nonisolated private func performLocationReport(latitude: Double, longitude: Double) async throws {
        let params = LocationReportParams(
            pLatitude: latitude,
            pLongitude: longitude
        )

        try await supabase
            .rpc("upsert_player_location", params: params)
            .execute()
    }

    /// 标记玩家离线
    private func markOffline() async {
        do {
            try await supabase
                .rpc("mark_player_offline")
                .execute()

            print("[PlayerLocationManager] 已标记为离线")

        } catch {
            print("[PlayerLocationManager] 标记离线失败: \(error)")
        }
    }

    /// 启动定时上报
    private func startReportTimer() {
        stopReportTimer()

        reportTimer = Timer.scheduledTimer(withTimeInterval: reportInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self,
                      let lastLocation = self.lastReportedLocation else { return }
                await self.reportLocation(lastLocation)
            }
        }

        print("[PlayerLocationManager] 定时上报已启动，间隔 \(Int(reportInterval)) 秒")
    }

    /// 停止定时上报
    private func stopReportTimer() {
        reportTimer?.invalidate()
        reportTimer = nil
    }
}
