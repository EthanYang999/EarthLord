//
//  BuildingManager.swift
//  EarthLord
//
//  建筑管理器
//  负责加载建筑模板、检查建造条件、管理建造流程
//

import Foundation
import Combine
import Supabase
import CoreLocation

/// 建筑管理器
/// 负责管理玩家建筑的建造、升级和状态维护
@MainActor
final class BuildingManager: ObservableObject {

    // MARK: - Singleton

    static let shared = BuildingManager()

    // MARK: - Published Properties

    /// 建筑模板（按 templateId 索引）
    @Published private(set) var buildingTemplates: [String: BuildingTemplate] = [:]

    /// 当前领地的玩家建筑
    @Published private(set) var playerBuildings: [PlayerBuilding] = []

    /// 是否正在加载
    @Published private(set) var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 模板是否已加载
    @Published private(set) var templatesLoaded = false

    // MARK: - Private Properties

    private let client = supabase

    /// 建造计时器
    private var constructionTimers: [UUID: Timer] = [:]

    /// 全局刷新定时器（每秒刷新UI以更新倒计时）
    private var refreshTimer: Timer?

    // MARK: - Initialization

    private init() {
        startRefreshTimer()
    }

    deinit {
        refreshTimer?.invalidate()
        // 直接在 deinit 中清理计时器，避免调用 MainActor 方法
        for (_, timer) in constructionTimers {
            timer.invalidate()
        }
        constructionTimers.removeAll()
    }

    // MARK: - Refresh Timer

    /// 启动全局刷新定时器
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let manager = self else { return }
            Task { @MainActor in
                manager.objectWillChange.send()
            }
        }
    }

    // MARK: - Template Loading

    /// 从 Bundle 加载建筑模板
    /// 应在应用启动时调用
    func loadTemplates() {
        guard !templatesLoaded else {
            print("[BuildingManager] ℹ️ 模板已加载，跳过")
            return
        }

        guard let url = Bundle.main.url(forResource: "building_templates", withExtension: "json") else {
            print("[BuildingManager] ❌ 找不到 building_templates.json")
            self.errorMessage = "找不到建筑模板文件"
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let collection = try decoder.decode(BuildingTemplateCollection.self, from: data)

            // 转换为字典以便快速查找
            var templateDict: [String: BuildingTemplate] = [:]
            for template in collection.templates {
                templateDict[template.templateId] = template
            }

            self.buildingTemplates = templateDict
            self.templatesLoaded = true

            print("[BuildingManager] ✅ 加载了 \(collection.templates.count) 个建筑模板")
        } catch {
            print("[BuildingManager] ❌ 解析建筑模板失败: \(error)")
            self.errorMessage = "解析建筑模板失败"
        }
    }

    /// 获取所有模板列表
    func getAllTemplates() -> [BuildingTemplate] {
        return Array(buildingTemplates.values).sorted { $0.tier < $1.tier }
    }

    /// 获取指定分类的模板
    func getTemplates(byCategory category: BuildingCategory) -> [BuildingTemplate] {
        return buildingTemplates.values
            .filter { $0.category == category }
            .sorted { $0.tier < $1.tier }
    }

    /// 获取指定模板
    func getTemplate(by templateId: String) -> BuildingTemplate? {
        return buildingTemplates[templateId]
    }

    // MARK: - Can Build Check

    /// 检查是否可以建造
    /// - Parameters:
    ///   - template: 建筑模板
    ///   - territoryId: 领地ID
    /// - Returns: 检查结果
    func canBuild(template: BuildingTemplate, territoryId: String) -> (canBuild: Bool, error: BuildingError?) {
        let inventoryManager = InventoryManager.shared

        // 1. 检查资源是否足够
        var missingResources: [String: Int] = [:]

        for (resourceName, requiredAmount) in template.requiredResources {
            // 通过名称查找物品定义
            guard let itemDef = inventoryManager.getItemDefinition(byName: resourceName) else {
                // 物品定义不存在，视为缺少全部数量
                missingResources[resourceName] = requiredAmount
                continue
            }

            // 统计背包中该物品的总数量
            let ownedAmount = inventoryManager.inventoryItems
                .filter { $0.itemId == itemDef.id }
                .reduce(0) { $0 + $1.quantity }

            if ownedAmount < requiredAmount {
                missingResources[resourceName] = requiredAmount - ownedAmount
            }
        }

        if !missingResources.isEmpty {
            return (false, .insufficientResources(missingResources))
        }

        // 2. 检查数量是否达到上限
        let existingCount = playerBuildings.filter {
            $0.territoryId == territoryId && $0.templateId == template.templateId
        }.count

        if existingCount >= template.maxPerTerritory {
            return (false, .maxBuildingsReached(template.maxPerTerritory))
        }

        // 3. 全部通过
        return (true, nil)
    }

    /// 简化版检查（仅检查资源）
    func canBuild(templateId: String, territoryId: String) -> MaterialCheckResult {
        guard let template = buildingTemplates[templateId] else {
            return MaterialCheckResult(canBuild: false, missingResources: [:])
        }

        let (canBuild, error) = self.canBuild(template: template, territoryId: territoryId)

        if canBuild {
            return .success
        }

        if case .insufficientResources(let missing) = error {
            return MaterialCheckResult(canBuild: false, missingResources: missing)
        }

        return MaterialCheckResult(canBuild: false, missingResources: [:])
    }

    // MARK: - Start Construction

    /// 使用建造请求开始建造
    /// - Parameter request: 建造请求
    /// - Returns: 新创建的建筑
    func startConstruction(request: BuildingConstructionRequest) async throws -> PlayerBuilding {
        return try await startConstruction(
            templateId: request.templateId,
            territoryId: request.territoryId,
            location: (lat: request.location.latitude, lon: request.location.longitude)
        )
    }

    /// 开始建造建筑
    /// - Parameters:
    ///   - templateId: 模板ID
    ///   - territoryId: 领地ID
    ///   - location: 建筑位置（可选）
    /// - Returns: 新创建的建筑，失败则抛出错误
    func startConstruction(
        templateId: String,
        territoryId: String,
        location: (lat: Double, lon: Double)? = nil
    ) async throws -> PlayerBuilding {
        // 1. 检查用户登录状态
        guard let userId = try? await client.auth.session.user.id else {
            throw BuildingError.notAuthenticated
        }

        // 2. 检查模板是否存在
        guard let template = buildingTemplates[templateId] else {
            throw BuildingError.templateNotFound
        }

        // 3. 检查是否可以建造
        let (canBuild, error) = self.canBuild(template: template, territoryId: territoryId)
        if !canBuild, let error = error {
            throw error
        }

        // 4. 扣除资源
        let inventoryManager = InventoryManager.shared
        for (resourceName, requiredAmount) in template.requiredResources {
            guard let itemDef = inventoryManager.getItemDefinition(byName: resourceName) else {
                continue
            }

            var remainingToRemove = requiredAmount

            // 遍历背包中的该物品并扣除
            for inventoryItem in inventoryManager.inventoryItems where inventoryItem.itemId == itemDef.id {
                if remainingToRemove <= 0 { break }

                let removeQuantity = min(inventoryItem.quantity, remainingToRemove)
                let success = await inventoryManager.removeItem(
                    inventoryItemId: inventoryItem.id,
                    quantity: removeQuantity
                )

                if success {
                    remainingToRemove -= removeQuantity
                    print("[BuildingManager] ✅ 扣除资源: \(resourceName) x\(removeQuantity)")
                }
            }
        }

        // 5. 创建建筑记录
        let now = Date()
        let completedAt = now.addingTimeInterval(TimeInterval(template.buildTimeSeconds))

        let insertData = InsertPlayerBuilding(
            userId: userId,
            territoryId: territoryId,
            templateId: templateId,
            buildingName: template.name,
            status: BuildingStatus.constructing.rawValue,
            level: 1,
            locationLat: location?.lat,
            locationLon: location?.lon,
            buildStartedAt: now,
            buildCompletedAt: completedAt
        )

        do {
            let response: [PlayerBuilding] = try await client
                .from("player_buildings")
                .insert(insertData)
                .select()
                .execute()
                .value

            guard let building = response.first else {
                throw BuildingError.databaseError("插入记录失败")
            }

            print("[BuildingManager] ✅ 开始建造: \(template.name)，预计完成: \(completedAt)")

            // 6. 启动建造计时器
            startConstructionTimer(for: building)

            // 7. 刷新建筑列表
            await fetchPlayerBuildings(territoryId: territoryId)

            return building

        } catch let error as BuildingError {
            throw error
        } catch {
            throw BuildingError.databaseError(error.localizedDescription)
        }
    }

    // MARK: - Complete Construction

    /// 完成建造
    /// - Parameter buildingId: 建筑ID
    func completeConstruction(buildingId: UUID) async throws {
        // 1. 查找建筑
        guard let building = playerBuildings.first(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound
        }

        // 2. 检查是否已到完成时间
        guard building.isConstructionComplete else {
            print("[BuildingManager] ⚠️ 建筑尚未完成建造")
            return
        }

        // 3. 更新状态为 active
        let updateData = UpdatePlayerBuilding(status: .active)

        do {
            try await client
                .from("player_buildings")
                .update(updateData)
                .eq("id", value: buildingId.uuidString)
                .execute()

            print("[BuildingManager] ✅ 建造完成: \(building.buildingName)")

            // 4. 停止计时器
            stopConstructionTimer(for: buildingId)

            // 5. 刷新建筑列表
            await fetchPlayerBuildings(territoryId: building.territoryId)

        } catch {
            throw BuildingError.databaseError(error.localizedDescription)
        }
    }

    // MARK: - Upgrade Building

    /// 升级建筑
    /// - Parameter buildingId: 建筑ID
    /// - Returns: 升级后的建筑
    func upgradeBuilding(buildingId: UUID) async throws -> PlayerBuilding {
        // 1. 检查用户登录状态
        guard let _ = try? await client.auth.session.user.id else {
            throw BuildingError.notAuthenticated
        }

        // 2. 查找建筑
        guard let building = playerBuildings.first(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound
        }

        // 3. 检查状态：只有 active 才能升级
        guard building.status == .active else {
            throw BuildingError.invalidStatus
        }

        // 4. 获取模板并检查等级
        guard let template = buildingTemplates[building.templateId] else {
            throw BuildingError.templateNotFound
        }

        let nextLevel = building.level + 1
        guard nextLevel <= template.maxLevel else {
            throw BuildingError.maxLevelReached
        }

        // 5. 检查升级所需资源（升级消耗 = 基础消耗 * 当前等级）
        let inventoryManager = InventoryManager.shared
        var missingResources: [String: Int] = [:]

        for (resourceName, baseAmount) in template.requiredResources {
            let requiredAmount = baseAmount * building.level

            guard let itemDef = inventoryManager.getItemDefinition(byName: resourceName) else {
                missingResources[resourceName] = requiredAmount
                continue
            }

            let ownedAmount = inventoryManager.inventoryItems
                .filter { $0.itemId == itemDef.id }
                .reduce(0) { $0 + $1.quantity }

            if ownedAmount < requiredAmount {
                missingResources[resourceName] = requiredAmount - ownedAmount
            }
        }

        if !missingResources.isEmpty {
            throw BuildingError.insufficientResources(missingResources)
        }

        // 6. 扣除升级资源
        for (resourceName, baseAmount) in template.requiredResources {
            let requiredAmount = baseAmount * building.level

            guard let itemDef = inventoryManager.getItemDefinition(byName: resourceName) else {
                continue
            }

            var remainingToRemove = requiredAmount

            for inventoryItem in inventoryManager.inventoryItems where inventoryItem.itemId == itemDef.id {
                if remainingToRemove <= 0 { break }

                let removeQuantity = min(inventoryItem.quantity, remainingToRemove)
                let success = await inventoryManager.removeItem(
                    inventoryItemId: inventoryItem.id,
                    quantity: removeQuantity
                )

                if success {
                    remainingToRemove -= removeQuantity
                }
            }
        }

        // 7. 更新建筑状态（升级时间 = 基础时间 * 等级）
        let now = Date()
        let upgradeTime = template.buildTimeSeconds * nextLevel
        let completedAt = now.addingTimeInterval(TimeInterval(upgradeTime))

        let updateData = UpdatePlayerBuilding(
            level: nextLevel,
            buildStartedAt: now,
            buildCompletedAt: completedAt
        )

        do {
            try await client
                .from("player_buildings")
                .update(updateData)
                .eq("id", value: buildingId.uuidString)
                .execute()

            print("[BuildingManager] ✅ 开始升级到 Lv.\(nextLevel)，预计完成: \(completedAt)")

            // 8. 刷新并启动计时器
            await fetchPlayerBuildings(territoryId: building.territoryId)

            if let updatedBuilding = playerBuildings.first(where: { $0.id == buildingId }) {
                startConstructionTimer(for: updatedBuilding)
                return updatedBuilding
            }

            throw BuildingError.buildingNotFound

        } catch let error as BuildingError {
            throw error
        } catch {
            throw BuildingError.databaseError(error.localizedDescription)
        }
    }

    // MARK: - Demolish Building

    /// 拆除建筑
    /// - Parameter buildingId: 建筑ID
    /// - Returns: 是否成功
    func demolishBuilding(buildingId: UUID) async throws {
        // 1. 检查用户登录状态
        guard let _ = try? await client.auth.session.user.id else {
            throw BuildingError.notAuthenticated
        }

        // 2. 查找建筑
        guard let building = playerBuildings.first(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound
        }

        // 3. 检查状态：只有 active 才能拆除
        guard building.status == .active else {
            throw BuildingError.invalidStatus
        }

        // 4. 删除数据库记录
        do {
            try await client
                .from("player_buildings")
                .delete()
                .eq("id", value: buildingId.uuidString)
                .execute()

            print("[BuildingManager] ✅ 已拆除建筑: \(building.buildingName)")

            // 5. 刷新建筑列表
            await fetchPlayerBuildings(territoryId: building.territoryId)

        } catch {
            throw BuildingError.databaseError(error.localizedDescription)
        }
    }

    // MARK: - Fetch Buildings

    /// 获取玩家在指定领地的建筑
    /// - Parameter territoryId: 领地ID
    func fetchPlayerBuildings(territoryId: String) async {
        guard let userId = try? await client.auth.session.user.id else {
            print("[BuildingManager] ⚠️ 用户未登录")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let buildings: [PlayerBuilding] = try await client
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("territory_id", value: territoryId)
                .order("created_at", ascending: false)
                .execute()
                .value

            self.playerBuildings = buildings

            print("[BuildingManager] ✅ 加载了 \(buildings.count) 个建筑 (领地: \(territoryId))")

            // 为建造中的建筑启动计时器
            for building in buildings where building.status == .constructing {
                startConstructionTimer(for: building)
            }

        } catch {
            print("[BuildingManager] ❌ 加载建筑失败: \(error)")
            self.errorMessage = "加载建筑失败"
        }
    }

    /// 获取玩家所有建筑（跨领地）
    func fetchAllPlayerBuildings() async {
        guard let userId = try? await client.auth.session.user.id else {
            print("[BuildingManager] ⚠️ 用户未登录")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let buildings: [PlayerBuilding] = try await client
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            self.playerBuildings = buildings

            print("[BuildingManager] ✅ 加载了 \(buildings.count) 个建筑（全部领地）")

            // 为建造中的建筑启动计时器
            for building in buildings where building.status == .constructing {
                startConstructionTimer(for: building)
            }

        } catch {
            print("[BuildingManager] ❌ 加载建筑失败: \(error)")
            self.errorMessage = "加载建筑失败"
        }
    }

    /// 获取指定模板的玩家建筑数量
    func getBuildingCount(templateId: String, territoryId: String) -> Int {
        return playerBuildings.filter {
            $0.templateId == templateId && $0.territoryId == territoryId
        }.count
    }

    // MARK: - Construction Timer

    /// 启动建造计时器
    private func startConstructionTimer(for building: PlayerBuilding) {
        guard building.status == .constructing,
              let completedAt = building.buildCompletedAt else {
            return
        }

        // 如果已有计时器，先停止
        stopConstructionTimer(for: building.id)

        let remainingTime = completedAt.timeIntervalSinceNow

        guard remainingTime > 0 else {
            // 已到完成时间，直接完成
            Task {
                try? await completeConstruction(buildingId: building.id)
            }
            return
        }

        // 创建计时器
        let timer = Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { [weak self] _ in
            guard let manager = self else { return }
            Task { @MainActor in
                try? await manager.completeConstruction(buildingId: building.id)
            }
        }

        constructionTimers[building.id] = timer
        print("[BuildingManager] ⏱️ 启动计时器: \(building.buildingName)，剩余 \(Int(remainingTime)) 秒")
    }

    /// 停止建造计时器
    private func stopConstructionTimer(for buildingId: UUID) {
        if let timer = constructionTimers[buildingId] {
            timer.invalidate()
            constructionTimers.removeValue(forKey: buildingId)
        }
    }

    /// 停止所有计时器
    func stopAllTimers() {
        for (_, timer) in constructionTimers {
            timer.invalidate()
        }
        constructionTimers.removeAll()
        print("[BuildingManager] ⏱️ 已停止所有计时器")
    }

    // MARK: - Location Validation

    /// 检查位置是否在领地多边形内（射线法）
    /// - Parameters:
    ///   - point: 要检查的坐标点
    ///   - polygon: 领地边界点数组
    /// - Returns: 是否在多边形内
    func isPointInPolygon(_ point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
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

    /// 获取模板（别名方法，用于视图层）
    func getTemplate(for templateId: String) -> BuildingTemplate? {
        return buildingTemplates[templateId]
    }
}
