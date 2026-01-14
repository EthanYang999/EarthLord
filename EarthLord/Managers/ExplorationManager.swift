//
//  ExplorationManager.swift
//  EarthLord
//
//  Created on 2025/1/9.
//
//  探索管理器
//  追踪玩家行走距离，计算探索奖励，保存到数据库
//

import Foundation
import CoreLocation
import Combine
import UIKit
import Supabase

// MARK: - 数据库模型

/// 插入探索记录的请求模型
struct InsertExplorationSession: Codable {
    let userId: UUID
    let startTime: Date
    let startLat: Double?
    let startLng: Double?
    let status: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case startTime = "start_time"
        case startLat = "start_lat"
        case startLng = "start_lng"
        case status
    }
}

/// 简单更新探索记录的请求模型
struct SimpleUpdateSession: Codable {
    let endTime: String
    let duration: Int
    let totalDistance: Double
    let rewardTier: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case endTime = "end_time"
        case duration
        case totalDistance = "total_distance"
        case rewardTier = "reward_tier"
        case status
    }
}

/// 状态更新模型
struct StatusUpdate: Codable {
    let status: String
}

/// 探索记录响应模型
struct DBExplorationSession: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let startTime: Date
    let endTime: Date?
    let duration: Int?
    let startLat: Double?
    let startLng: Double?
    let endLat: Double?
    let endLng: Double?
    let totalDistance: Double
    let rewardTier: String
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case duration
        case startLat = "start_lat"
        case startLng = "start_lng"
        case endLat = "end_lat"
        case endLng = "end_lng"
        case totalDistance = "total_distance"
        case rewardTier = "reward_tier"
        case status
        case createdAt = "created_at"
    }
}

/// 探索管理器
/// 负责追踪玩家探索过程中的行走距离，并根据距离计算奖励
@MainActor
final class ExplorationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ExplorationManager()

    // MARK: - Published Properties

    /// 是否正在探索
    @Published private(set) var isExploring: Bool = false

    /// 当前行走距离（米）
    @Published private(set) var currentDistance: CLLocationDistance = 0

    /// 探索开始时间
    @Published private(set) var startTime: Date?

    /// 探索时长（秒）
    @Published private(set) var elapsedTime: TimeInterval = 0

    /// 最新探索结果
    @Published private(set) var lastExplorationResult: ExplorationResult?

    /// 当前奖励等级（实时计算）
    @Published private(set) var currentRewardTier: RewardTier = .none

    /// 是否正在保存
    @Published private(set) var isSaving: Bool = false

    // MARK: - POI 相关属性 (Day 22)

    /// 当前探索发现的 POI 列表
    @Published private(set) var discoveredPOIs: [POI] = []

    /// 是否显示 POI 接近弹窗
    @Published var showPOIPopup: Bool = false

    /// 当前接近的 POI
    @Published private(set) var currentProximityPOI: POI?

    /// 已搜刮的 POI ID 集合
    @Published private(set) var scavengedPOIIds: Set<String> = []

    /// 最近搜刮获得的物品（用于显示结果）
    @Published private(set) var lastScavengeItems: [GeneratedRewardItem] = []

    /// 最近搜刮的 POI 名称
    @Published private(set) var lastScavengedPOIName: String = ""

    /// 是否显示搜刮结果
    @Published var showScavengeResult: Bool = false

    // MARK: - Private Properties

    /// 起始位置
    private var startLocation: CLLocation?

    /// 上一个位置（用于计算增量距离）
    private var lastLocation: CLLocation?

    /// 位置订阅
    private var locationSubscription: AnyCancellable?

    /// 计时器（更新时长）
    private var timer: Timer?

    /// 当前探索会话ID
    private var currentSessionId: UUID?

    /// Supabase 客户端
    private let client = supabase

    /// 累计历史行走距离（用于排行榜，从 UserDefaults 读取）
    private var totalHistoryDistance: CLLocationDistance {
        get { UserDefaults.standard.double(forKey: "exploration_total_distance") }
        set { UserDefaults.standard.set(newValue, forKey: "exploration_total_distance") }
    }

    /// 累计历史探索面积（简化计算，用于排行榜）
    private var totalHistoryArea: Double {
        get { UserDefaults.standard.double(forKey: "exploration_total_area") }
        set { UserDefaults.standard.set(newValue, forKey: "exploration_total_area") }
    }

    // MARK: - POI 围栏管理 (Day 22)

    /// 围栏管理器（独立的 CLLocationManager 用于围栏监控）
    private var geofenceManager: CLLocationManager?

    /// 围栏代理
    private var geofenceDelegate: GeofenceDelegate?

    /// 当前监控的围栏区域
    private var monitoredRegions: [String: CLCircularRegion] = [:]

    /// 保存的 LocationManager 引用
    private weak var activeLocationManager: LocationManager?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 开始探索
    /// - Parameter locationManager: 位置管理器
    func startExploration(with locationManager: LocationManager) async {
        guard !isExploring else {
            print("[ExplorationManager] 已在探索中")
            return
        }

        // 初始化状态
        isExploring = true
        currentDistance = 0
        startTime = Date()
        elapsedTime = 0
        startLocation = nil
        lastLocation = nil
        lastLocationTimestamp = nil
        currentRewardTier = .none

        print("[ExplorationManager] 🚀 开始探索，等待位置更新...")

        // 保存 LocationManager 引用
        activeLocationManager = locationManager

        // 创建数据库记录
        await createExplorationSession()

        // 激活玩家位置上报（多人机制）
        PlayerLocationManager.shared.activate(with: locationManager)

        // Day 22: 搜索附近 POI 并设置围栏
        if let location = locationManager.userLocation {
            await searchAndSetupPOIs(at: location)
        }

        // 订阅位置更新
        locationSubscription = locationManager.$userLocation
            .compactMap { $0 }
            .sink { [weak self] coordinate in
                self?.handleLocationUpdate(coordinate)
            }

        // 启动计时器
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.updateElapsedTime()
            }
        }

        // 轻微震动提示开始
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// 停止探索并返回结果
    /// - Returns: 探索结果
    @discardableResult
    func stopExploration() async -> ExplorationResult? {
        guard isExploring else {
            print("[ExplorationManager] 未在探索中")
            return nil
        }

        // 停止订阅和计时器
        locationSubscription?.cancel()
        locationSubscription = nil
        timer?.invalidate()
        timer = nil

        // 停用玩家位置上报（多人机制）
        PlayerLocationManager.shared.deactivate()

        isSaving = true

        // 使用新的 RewardGenerator 生成奖励
        let tier = RewardGenerator.calculateTier(distance: currentDistance)
        let generatedRewards = RewardGenerator.generateRewards(
            distance: currentDistance,
            inventoryManager: InventoryManager.shared
        )

        // 转换为 ObtainedItem
        let obtainedItems = generatedRewards.map { reward in
            ObtainedItem(
                id: reward.itemId.uuidString,
                itemName: reward.itemName,
                quantity: reward.quantity,
                quality: InventoryManager.stringToQuality(reward.quality)
            )
        }

        // 计算探索结果
        let durationMinutes = Int(elapsedTime / 60)
        let exploredArea = estimateExploredArea()

        let result = ExplorationResult(
            walkDistance: currentDistance,
            totalWalkDistance: totalHistoryDistance + currentDistance,
            exploredArea: exploredArea,
            totalExploredArea: totalHistoryArea + exploredArea,
            durationMinutes: max(1, durationMinutes),
            walkDistanceRank: calculateRank(for: totalHistoryDistance + currentDistance),
            exploredAreaRank: calculateRank(for: totalHistoryArea + exploredArea),
            obtainedItems: obtainedItems,
            rewardTier: tier
        )

        lastExplorationResult = result

        // 保存到数据库
        await saveExplorationResult(result: result, rewards: generatedRewards, tier: tier)

        // 添加物品到背包
        await addRewardsToInventory(rewards: generatedRewards)

        // 更新历史数据
        totalHistoryDistance += currentDistance
        totalHistoryArea += exploredArea

        // Day 22: 清理 POI 和围栏
        clearPOIs()

        // 重置状态
        isExploring = false
        isSaving = false
        currentSessionId = nil
        activeLocationManager = nil

        print("[ExplorationManager] ⏹️ 探索结束，行走 \(String(format: "%.0f", currentDistance))m，获得 \(obtainedItems.count) 件物品，等级: \(tier.displayName)")

        // 成功震动
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)

        return result
    }

    /// 取消探索（不计算奖励）
    func cancelExploration() async {
        guard isExploring else { return }

        print("[ExplorationManager] ⚠️ 取消探索中...")

        locationSubscription?.cancel()
        locationSubscription = nil
        timer?.invalidate()
        timer = nil

        // 更新数据库记录为已取消
        if let sessionId = currentSessionId {
            await updateSessionStatus(sessionId: sessionId, status: "cancelled")
        }

        // Day 22: 清理 POI 和围栏
        clearPOIs()

        isExploring = false
        currentDistance = 0
        startTime = nil
        elapsedTime = 0
        currentRewardTier = .none
        currentSessionId = nil
        startLocation = nil
        lastLocation = nil
        lastLocationTimestamp = nil
        activeLocationManager = nil

        print("[ExplorationManager] ❌ 探索已取消（可能因超速或用户取消）")
    }

    // MARK: - Private Properties - Speed Detection

    /// 上次位置时间戳（用于速度计算）
    private var lastLocationTimestamp: Date?

    /// 最大允许速度（km/h）- 超过则停止探索
    private let maxSpeedKMH: Double = 20.0

    // MARK: - Private Methods - Location

    /// 处理位置更新
    private func handleLocationUpdate(_ coordinate: CLLocationCoordinate2D) {
        let newLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let now = Date()

        print("[ExplorationManager] 📡 收到位置更新: \(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude))")

        // 第一个位置点
        if startLocation == nil {
            startLocation = newLocation
            lastLocation = newLocation
            lastLocationTimestamp = now
            print("[ExplorationManager] 📍 记录探索起点")
            return
        }

        // 计算与上一个位置的距离
        guard let last = lastLocation else {
            print("[ExplorationManager] ⚠️ 无上一个位置")
            return
        }
        let distance = newLocation.distance(from: last)

        // 过滤 GPS 漂移（移动小于 3 米忽略）
        guard distance >= 3.0 else {
            print("[ExplorationManager] 📏 移动 \(String(format: "%.1f", distance))m < 3m，忽略（GPS 漂移）")
            return
        }

        // 速度检测
        if let lastTimestamp = lastLocationTimestamp {
            let timeDiff = now.timeIntervalSince(lastTimestamp)
            if timeDiff > 0 {
                let speedMPS = distance / timeDiff
                let speedKMH = speedMPS * 3.6

                print("[ExplorationManager] 🚗 速度: \(String(format: "%.1f", speedKMH)) km/h (移动 \(String(format: "%.1f", distance))m，用时 \(String(format: "%.1f", timeDiff))s)")

                // 超速检测
                if speedKMH > maxSpeedKMH {
                    print("[ExplorationManager] 🚨 超速！\(String(format: "%.1f", speedKMH)) km/h > \(maxSpeedKMH) km/h，自动停止探索")

                    // 异步停止探索
                    Task {
                        await self.cancelExploration()
                    }
                    return
                }
            }
        }

        // 过滤异常移动（单次移动超过 100 米，可能是 GPS 跳点）
        guard distance <= 100.0 else {
            print("[ExplorationManager] ⚠️ 移动距离异常 \(String(format: "%.1f", distance))m > 100m，忽略（GPS 跳点）")
            return
        }

        // 累加距离
        currentDistance += distance
        lastLocation = newLocation
        lastLocationTimestamp = now

        // 更新奖励等级
        currentRewardTier = RewardGenerator.calculateTier(distance: currentDistance)

        print("[ExplorationManager] ✅ 有效移动 +\(String(format: "%.1f", distance))m，累计: \(String(format: "%.0f", currentDistance))m，等级: \(currentRewardTier.displayName)")
    }

    /// 更新探索时长
    private func updateElapsedTime() {
        guard let start = startTime else { return }
        elapsedTime = Date().timeIntervalSince(start)
    }

    // MARK: - Private Methods - Database

    /// 创建探索会话记录
    private func createExplorationSession() async {
        guard let userId = try? await client.auth.session.user.id else {
            print("[ExplorationManager] ⚠️ 用户未登录，跳过数据库记录")
            return
        }

        let session = InsertExplorationSession(
            userId: userId,
            startTime: startTime ?? Date(),
            startLat: startLocation?.coordinate.latitude,
            startLng: startLocation?.coordinate.longitude,
            status: "active"
        )

        do {
            let response: [DBExplorationSession] = try await client
                .from("exploration_sessions")
                .insert(session)
                .select()
                .execute()
                .value

            if let created = response.first {
                currentSessionId = created.id
                print("[ExplorationManager] ✅ 创建探索记录: \(created.id)")
            }
        } catch {
            print("[ExplorationManager] ❌ 创建探索记录失败: \(error)")
        }
    }

    /// 保存探索结果
    private func saveExplorationResult(result: ExplorationResult, rewards: [GeneratedRewardItem], tier: RewardTier) async {
        guard let sessionId = currentSessionId else {
            print("[ExplorationManager] ⚠️ 无探索会话ID，跳过保存")
            return
        }

        // 构建奖励物品 JSON
        let itemsJson: [[String: Any]] = rewards.map { reward in
            var item: [String: Any] = [
                "item_id": reward.itemId.uuidString,
                "item_name": reward.itemName,
                "quantity": reward.quantity,
                "rarity": reward.rarity
            ]
            if let quality = reward.quality {
                item["quality"] = quality
            }
            return item
        }

        do {
            // 使用简单更新模型
            let updateData = SimpleUpdateSession(
                endTime: ISO8601DateFormatter().string(from: Date()),
                duration: Int(elapsedTime),
                totalDistance: currentDistance,
                rewardTier: tier.rawValue,
                status: "completed"
            )

            try await client
                .from("exploration_sessions")
                .update(updateData)
                .eq("id", value: sessionId.uuidString)
                .execute()

            print("[ExplorationManager] ✅ 保存探索结果成功")
        } catch {
            print("[ExplorationManager] ❌ 保存探索结果失败: \(error)")
        }
    }

    /// 更新会话状态
    private func updateSessionStatus(sessionId: UUID, status: String) async {
        do {
            try await client
                .from("exploration_sessions")
                .update(StatusUpdate(status: status))
                .eq("id", value: sessionId.uuidString)
                .execute()

            print("[ExplorationManager] ✅ 更新会话状态: \(status)")
        } catch {
            print("[ExplorationManager] ❌ 更新会话状态失败: \(error)")
        }
    }

    /// 添加奖励物品到背包
    private func addRewardsToInventory(rewards: [GeneratedRewardItem]) async {
        let inventoryManager = InventoryManager.shared

        for reward in rewards {
            let success = await inventoryManager.addItem(
                itemId: reward.itemId,
                quantity: reward.quantity,
                quality: reward.quality
            )

            if success {
                print("[ExplorationManager] ✅ 添加物品到背包: \(reward.itemName) x\(reward.quantity)")
            } else {
                print("[ExplorationManager] ❌ 添加物品失败: \(reward.itemName)")
            }
        }
    }

    // MARK: - Private Methods - Calculation

    /// 估算探索面积（简化计算）
    private func estimateExploredArea() -> Double {
        // 假设走的是圆形路径，周长 = 距离，半径 = 距离 / (2π)
        // 面积 = π * r² = 距离² / (4π)
        // 但这个估算偏大，乘以 0.3 系数调整
        return (currentDistance * currentDistance) / (4 * .pi) * 0.3
    }

    /// 计算排名（简化版，基于本地数据）
    private func calculateRank(for value: Double) -> Int {
        // 简化实现：根据数值范围返回排名
        // 实际项目中应该从服务器获取
        switch value {
        case 0..<100:
            return Int.random(in: 500...1000)
        case 100..<500:
            return Int.random(in: 200...499)
        case 500..<1000:
            return Int.random(in: 100...199)
        case 1000..<5000:
            return Int.random(in: 50...99)
        case 5000..<10000:
            return Int.random(in: 20...49)
        default:
            return Int.random(in: 1...19)
        }
    }
}

// MARK: - Convenience Methods

extension ExplorationManager {

    /// 格式化时长显示
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// 格式化距离显示
    static func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }
}

// MARK: - POI 搜刮功能 (Day 22)

extension ExplorationManager {

    /// 搜索附近 POI 并设置围栏
    private func searchAndSetupPOIs(at location: CLLocationCoordinate2D) async {
        print("[ExplorationManager] 🔍 开始搜索附近 POI...")

        // 查询附近玩家数量（多人机制）
        let playerLocationManager = PlayerLocationManager.shared
        let nearbyCount = await playerLocationManager.queryNearbyPlayers(at: location)
        let recommendedPOICount = playerLocationManager.getRecommendedPOICount(for: nearbyCount)

        print("[ExplorationManager] 👥 附近玩家: \(nearbyCount) 人，推荐 POI 数量: \(recommendedPOICount)")

        // 使用 POISearchManager 搜索，传入推荐数量
        let pois = await POISearchManager.shared.searchNearbyPOIs(
            at: location,
            maxCount: recommendedPOICount
        )

        // 更新 POI 列表
        discoveredPOIs = pois
        scavengedPOIIds = []

        print("[ExplorationManager] 📍 发现 \(pois.count) 个 POI")

        // 设置地理围栏
        setupGeofences(for: pois)
    }

    /// 为 POI 创建地理围栏
    private func setupGeofences(for pois: [POI]) {
        // 创建围栏管理器
        geofenceDelegate = GeofenceDelegate { [weak self] region in
            Task { @MainActor in
                self?.handleEnterRegion(region)
            }
        }

        geofenceManager = CLLocationManager()
        geofenceManager?.delegate = geofenceDelegate
        geofenceManager?.allowsBackgroundLocationUpdates = false

        // 清除现有围栏
        for region in monitoredRegions.values {
            geofenceManager?.stopMonitoring(for: region)
        }
        monitoredRegions.removeAll()

        // 为每个 POI 创建围栏（最多 20 个）
        let poisToMonitor = Array(pois.prefix(20))

        for poi in poisToMonitor {
            let region = CLCircularRegion(
                center: poi.coordinate,
                radius: POISearchManager.triggerRadius,
                identifier: poi.id
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false

            geofenceManager?.startMonitoring(for: region)
            monitoredRegions[poi.id] = region

            print("[ExplorationManager] 🎯 创建围栏: \(poi.name) (ID: \(poi.id))")
        }

        print("[ExplorationManager] ✅ 已设置 \(poisToMonitor.count) 个围栏")
    }

    /// 处理进入围栏事件
    func handleEnterRegion(_ region: CLRegion) {
        guard isExploring else { return }

        let poiId = region.identifier

        // 检查是否已搜刮
        guard !scavengedPOIIds.contains(poiId) else {
            print("[ExplorationManager] ℹ️ POI 已搜刮过: \(poiId)")
            return
        }

        // 查找对应的 POI
        guard let poi = discoveredPOIs.first(where: { $0.id == poiId }) else {
            print("[ExplorationManager] ⚠️ 未找到 POI: \(poiId)")
            return
        }

        print("[ExplorationManager] 🏠 进入 POI 范围: \(poi.name)")

        // 设置当前接近的 POI 并显示弹窗
        currentProximityPOI = poi
        showPOIPopup = true

        // 震动提示
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    /// 执行搜刮
    /// 所有物品由 AI 实时生成，物品稀有度由 POI 危险等级决定
    /// - Parameter poi: 要搜刮的 POI
    /// - Returns: 获得的物品列表
    func scavengePOI(_ poi: POI) async -> [GeneratedRewardItem] {
        print("[ExplorationManager] 🔦 开始搜刮: \(poi.name) (危险等级: \(poi.dangerLevel))")

        // 随机生成 1-3 件物品
        let itemCount = Int.random(in: 1...3)

        // 使用 AI 生成所有物品
        let aiGenerator = AIItemGenerator.shared
        var generatedItems: [GeneratedRewardItem] = []

        // 调用 AI 生成物品
        if let aiItems = await aiGenerator.generateItems(for: poi, count: itemCount) {
            // AI 生成成功
            generatedItems = aiGenerator.convertToRewardItems(aiItems, from: poi)
            print("[ExplorationManager] 🤖 AI 成功生成 \(generatedItems.count) 件物品")
        } else {
            // AI 生成失败，使用本地备用方案
            print("[ExplorationManager] ⚠️ AI 生成失败，使用备用方案")
            generatedItems = generateFallbackItems(for: poi, count: itemCount)
        }

        // 添加物品到背包（AI 生成的物品使用虚拟 UUID）
        let inventoryManager = InventoryManager.shared
        for item in generatedItems {
            // AI 物品暂时不添加到背包（因为没有对应的物品定义 ID）
            // 后续可以扩展为动态创建物品定义
            print("[ExplorationManager] ✅ 搜刮获得: \(item.itemName) [\(item.rarity)]")
        }

        // 标记 POI 为已搜刮
        scavengedPOIIds.insert(poi.id)

        // 关闭接近弹窗
        showPOIPopup = false
        currentProximityPOI = nil

        // 保存搜刮结果用于显示
        lastScavengeItems = generatedItems
        lastScavengedPOIName = poi.name
        showScavengeResult = true

        // 成功震动
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)

        print("[ExplorationManager] 🎉 搜刮完成，获得 \(generatedItems.count) 件物品")

        return generatedItems
    }

    /// 生成备用物品（当 AI 服务不可用时）
    /// - Parameters:
    ///   - poi: POI 信息
    ///   - count: 物品数量
    /// - Returns: 备用物品列表
    private func generateFallbackItems(for poi: POI, count: Int) -> [GeneratedRewardItem] {
        // 根据 POI 类型生成预设物品名称
        let presetItems: [(name: String, category: String)] = {
            switch poi.type {
            case .hospital, .pharmacy:
                return [("急救包", "医疗"), ("绷带", "医疗"), ("止痛药", "医疗")]
            case .supermarket, .restaurant:
                return [("罐头食品", "食物"), ("瓶装水", "食物"), ("压缩饼干", "食物")]
            case .hardware, .gasStation, .autoRepair:
                return [("手电筒", "工具"), ("绳索", "工具"), ("工具箱", "工具")]
            case .police, .fireStation:
                return [("警棍", "武器"), ("防弹衣", "防具"), ("对讲机", "工具")]
            default:
                return [("杂物", "材料"), ("旧报纸", "材料"), ("破布", "材料")]
            }
        }()

        // 根据危险等级确定稀有度
        let rarities = getRarityForDangerLevel(poi.dangerLevel)

        var items: [GeneratedRewardItem] = []
        for i in 0..<count {
            let preset = presetItems[i % presetItems.count]
            let rarity = rarities.randomElement() ?? "common"

            items.append(GeneratedRewardItem(
                itemId: UUID(),
                itemName: preset.name,
                quantity: 1,
                quality: "normal",
                rarity: rarity,
                isAIGenerated: false,
                aiStory: nil,
                aiBonusEffect: nil
            ))
        }

        return items
    }

    /// 根据危险等级获取可能的稀有度列表
    private func getRarityForDangerLevel(_ level: Int) -> [String] {
        switch level {
        case 1, 2:
            return ["common", "common", "common", "uncommon"]
        case 3:
            return ["common", "uncommon", "uncommon", "rare"]
        case 4:
            return ["uncommon", "rare", "rare", "epic"]
        case 5:
            return ["rare", "epic", "epic", "legendary"]
        default:
            return ["common", "uncommon"]
        }
    }

    /// 关闭 POI 弹窗（稍后再说）
    func dismissPOIPopup() {
        showPOIPopup = false
        currentProximityPOI = nil
    }

    /// 关闭搜刮结果
    func dismissScavengeResult() {
        showScavengeResult = false
        lastScavengeItems = []
        lastScavengedPOIName = ""
    }

    /// 清理 POI 和围栏
    private func clearPOIs() {
        print("[ExplorationManager] 🧹 清理 POI 和围栏")

        // 停止所有围栏监控
        for region in monitoredRegions.values {
            geofenceManager?.stopMonitoring(for: region)
        }
        monitoredRegions.removeAll()

        // 释放围栏管理器
        geofenceManager?.delegate = nil
        geofenceManager = nil
        geofenceDelegate = nil

        // 清空 POI 数据
        discoveredPOIs = []
        scavengedPOIIds = []
        currentProximityPOI = nil
        showPOIPopup = false
        showScavengeResult = false
        lastScavengeItems = []
        lastScavengedPOIName = ""
    }

    /// 计算用户当前位置到 POI 的距离
    func distanceToPOI(_ poi: POI) -> CLLocationDistance? {
        guard let userLocation = activeLocationManager?.userLocation else {
            return nil
        }

        let userLoc = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let poiLoc = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)

        return userLoc.distance(from: poiLoc)
    }
}

// MARK: - Geofence Delegate

/// 围栏代理类
/// 用于接收地理围栏事件
class GeofenceDelegate: NSObject, CLLocationManagerDelegate {

    /// 进入围栏回调
    private let onEnterRegion: (CLRegion) -> Void

    init(onEnterRegion: @escaping (CLRegion) -> Void) {
        self.onEnterRegion = onEnterRegion
        super.init()
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("[GeofenceDelegate] 📍 进入围栏: \(region.identifier)")
        onEnterRegion(region)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("[GeofenceDelegate] 🚶 离开围栏: \(region.identifier)")
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("[GeofenceDelegate] ❌ 围栏监控失败: \(region?.identifier ?? "unknown") - \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        print("[GeofenceDelegate] ✅ 开始监控围栏: \(region.identifier)")
    }
}
