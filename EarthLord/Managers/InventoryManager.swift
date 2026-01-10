//
//  InventoryManager.swift
//  EarthLord
//
//  Created on 2025/1/10.
//
//  背包管理器
//  管理玩家背包数据，与 Supabase 数据库同步
//

import Foundation
import Combine
import Supabase

// MARK: - 数据库模型

/// 物品定义（数据库模型）
struct DBItemDefinition: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let icon: String?
    let rarity: String
    let category: String
    let weight: Double
    let volume: Double
    let hasQuality: Bool
    let stackLimit: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, rarity, category, weight, volume
        case hasQuality = "has_quality"
        case stackLimit = "stack_limit"
        case createdAt = "created_at"
    }

    /// 转换为 App 模型
    func toItemDefinition() -> ItemDefinition {
        ItemDefinition(
            id: id.uuidString,
            name: name,
            category: ItemCategory(rawValue: categoryDisplayName) ?? .misc,
            weight: weight,
            volume: volume,
            rarity: ItemRarity(rawValue: rarityDisplayName) ?? .common,
            description: description ?? "",
            hasQuality: hasQuality,
            stackLimit: stackLimit
        )
    }

    /// 稀有度显示名称
    private var rarityDisplayName: String {
        switch rarity {
        case "common": return "普通"
        case "uncommon": return "少见"
        case "rare": return "稀有"
        case "epic": return "史诗"
        case "legendary": return "传说"
        default: return "普通"
        }
    }

    /// 分类显示名称
    private var categoryDisplayName: String {
        switch category {
        case "water": return "水类"
        case "food": return "食物"
        case "medical": return "医疗"
        case "material": return "材料"
        case "tool": return "工具"
        case "weapon": return "武器"
        case "clothing": return "服装"
        case "misc": return "杂项"
        default: return "杂项"
        }
    }
}

/// 背包物品（数据库模型）
struct DBInventoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let itemId: UUID
    var quantity: Int
    let quality: String?
    let obtainedAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemId = "item_id"
        case quantity, quality
        case obtainedAt = "obtained_at"
        case updatedAt = "updated_at"
    }
}

/// 插入背包物品的请求模型
struct InsertInventoryItem: Codable {
    let userId: UUID
    let itemId: UUID
    var quantity: Int
    let quality: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case itemId = "item_id"
        case quantity, quality
    }
}

/// 更新背包物品的请求模型
struct UpdateInventoryItem: Codable {
    var quantity: Int
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case quantity
        case updatedAt = "updated_at"
    }
}

// MARK: - InventoryManager

/// 背包管理器
/// 负责管理玩家背包数据，与数据库同步
@MainActor
final class InventoryManager: ObservableObject {

    // MARK: - Singleton

    static let shared = InventoryManager()

    // MARK: - Published Properties

    /// 物品定义缓存
    @Published private(set) var itemDefinitions: [UUID: DBItemDefinition] = [:]

    /// 当前用户的背包物品
    @Published private(set) var inventoryItems: [DBInventoryItem] = []

    /// 是否正在加载
    @Published private(set) var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let client = supabase

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 加载物品定义（应用启动时调用一次）
    func loadItemDefinitions() async {
        do {
            let definitions: [DBItemDefinition] = try await client
                .from("item_definitions")
                .select()
                .execute()
                .value

            var cache: [UUID: DBItemDefinition] = [:]
            for def in definitions {
                cache[def.id] = def
            }
            self.itemDefinitions = cache

            print("[InventoryManager] ✅ 加载了 \(definitions.count) 个物品定义")
        } catch {
            print("[InventoryManager] ❌ 加载物品定义失败: \(error)")
            self.errorMessage = "加载物品定义失败"
        }
    }

    /// 加载当前用户的背包
    func loadInventory() async {
        guard let userId = try? await client.auth.session.user.id else {
            print("[InventoryManager] ⚠️ 用户未登录")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let items: [DBInventoryItem] = try await client
                .from("inventory_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            self.inventoryItems = items
            print("[InventoryManager] ✅ 加载了 \(items.count) 个背包物品")
        } catch {
            print("[InventoryManager] ❌ 加载背包失败: \(error)")
            self.errorMessage = "加载背包失败"
        }
    }

    /// 添加物品到背包
    /// - Parameters:
    ///   - itemId: 物品定义ID
    ///   - quantity: 数量
    ///   - quality: 品质（可选）
    func addItem(itemId: UUID, quantity: Int, quality: String? = nil) async -> Bool {
        guard let userId = try? await client.auth.session.user.id else {
            print("[InventoryManager] ⚠️ 用户未登录")
            return false
        }

        do {
            // 查找是否已有相同物品（相同 item_id 和 quality）
            let existingItems: [DBInventoryItem] = try await client
                .from("inventory_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("item_id", value: itemId.uuidString)
                .execute()
                .value

            // 找到匹配品质的物品
            let matchingItem = existingItems.first { item in
                if quality == nil && item.quality == nil {
                    return true
                }
                return item.quality == quality
            }

            if let existing = matchingItem {
                // 更新数量
                let newQuantity = existing.quantity + quantity
                let update = UpdateInventoryItem(quantity: newQuantity, updatedAt: Date())

                try await client
                    .from("inventory_items")
                    .update(update)
                    .eq("id", value: existing.id.uuidString)
                    .execute()

                print("[InventoryManager] ✅ 更新物品数量: \(existing.quantity) -> \(newQuantity)")
            } else {
                // 插入新物品
                let newItem = InsertInventoryItem(
                    userId: userId,
                    itemId: itemId,
                    quantity: quantity,
                    quality: quality
                )

                try await client
                    .from("inventory_items")
                    .insert(newItem)
                    .execute()

                print("[InventoryManager] ✅ 添加新物品到背包")
            }

            // 重新加载背包
            await loadInventory()
            return true

        } catch {
            print("[InventoryManager] ❌ 添加物品失败: \(error)")
            self.errorMessage = "添加物品失败"
            return false
        }
    }

    /// 批量添加物品到背包
    func addItems(_ items: [(itemId: UUID, quantity: Int, quality: String?)]) async -> Bool {
        var allSuccess = true
        for item in items {
            let success = await addItem(itemId: item.itemId, quantity: item.quantity, quality: item.quality)
            if !success {
                allSuccess = false
            }
        }
        return allSuccess
    }

    /// 移除物品
    func removeItem(inventoryItemId: UUID, quantity: Int) async -> Bool {
        guard let item = inventoryItems.first(where: { $0.id == inventoryItemId }) else {
            print("[InventoryManager] ⚠️ 物品不存在")
            return false
        }

        do {
            if item.quantity <= quantity {
                // 删除物品
                try await client
                    .from("inventory_items")
                    .delete()
                    .eq("id", value: inventoryItemId.uuidString)
                    .execute()

                print("[InventoryManager] ✅ 删除物品")
            } else {
                // 减少数量
                let newQuantity = item.quantity - quantity
                let update = UpdateInventoryItem(quantity: newQuantity, updatedAt: Date())

                try await client
                    .from("inventory_items")
                    .update(update)
                    .eq("id", value: inventoryItemId.uuidString)
                    .execute()

                print("[InventoryManager] ✅ 减少物品数量: \(item.quantity) -> \(newQuantity)")
            }

            await loadInventory()
            return true

        } catch {
            print("[InventoryManager] ❌ 移除物品失败: \(error)")
            self.errorMessage = "移除物品失败"
            return false
        }
    }

    /// 计算背包总重量
    func calculateTotalWeight() -> Double {
        var total = 0.0
        for item in inventoryItems {
            if let def = itemDefinitions[item.itemId] {
                total += def.weight * Double(item.quantity)
            }
        }
        return total
    }

    /// 获取物品定义（通过ID）
    func getItemDefinition(by id: UUID) -> DBItemDefinition? {
        return itemDefinitions[id]
    }

    /// 获取物品定义（通过名称）
    func getItemDefinition(byName name: String) -> DBItemDefinition? {
        return itemDefinitions.values.first { $0.name == name }
    }

    /// 根据稀有度获取物品定义列表
    func getItemDefinitions(byRarity rarity: String) -> [DBItemDefinition] {
        return itemDefinitions.values.filter { $0.rarity == rarity }
    }

    /// 转换品质枚举到数据库字符串
    static func qualityToString(_ quality: ItemQuality?) -> String? {
        guard let q = quality else { return nil }
        switch q {
        case .broken: return "broken"
        case .worn: return "worn"
        case .normal: return "normal"
        case .good: return "good"
        case .pristine: return "pristine"
        }
    }

    /// 转换数据库字符串到品质枚举
    static func stringToQuality(_ str: String?) -> ItemQuality? {
        guard let s = str else { return nil }
        switch s {
        case "broken": return .broken
        case "worn": return .worn
        case "normal": return .normal
        case "good": return .good
        case "pristine": return .pristine
        default: return nil
        }
    }
}
