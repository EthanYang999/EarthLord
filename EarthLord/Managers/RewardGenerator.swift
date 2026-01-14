//
//  RewardGenerator.swift
//  EarthLord
//
//  Created on 2025/1/10.
//
//  奖励生成器
//  根据行走距离生成探索奖励物品
//

import Foundation

// MARK: - 奖励等级

/// 奖励等级枚举
enum RewardTier: String, CaseIterable {
    case none = "none"
    case bronze = "bronze"
    case silver = "silver"
    case gold = "gold"
    case diamond = "diamond"

    /// 显示名称
    var displayName: String {
        switch self {
        case .none: return "无奖励"
        case .bronze: return "铜级"
        case .silver: return "银级"
        case .gold: return "金级"
        case .diamond: return "钻石级"
        }
    }

    /// 显示图标
    var icon: String {
        switch self {
        case .none: return "xmark.circle"
        case .bronze: return "🥉"
        case .silver: return "🥈"
        case .gold: return "🥇"
        case .diamond: return "💎"
        }
    }

    /// 物品数量
    var itemCount: Int {
        switch self {
        case .none: return 0
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .diamond: return 5
        }
    }

    /// 普通物品概率
    var commonProbability: Double {
        switch self {
        case .none: return 0
        case .bronze: return 0.90
        case .silver: return 0.70
        case .gold: return 0.50
        case .diamond: return 0.30
        }
    }

    /// 稀有物品概率
    var rareProbability: Double {
        switch self {
        case .none: return 0
        case .bronze: return 0.10
        case .silver: return 0.25
        case .gold: return 0.35
        case .diamond: return 0.40
        }
    }

    /// 史诗物品概率
    var epicProbability: Double {
        switch self {
        case .none: return 0
        case .bronze: return 0
        case .silver: return 0.05
        case .gold: return 0.15
        case .diamond: return 0.30
        }
    }
}

// MARK: - 生成的奖励物品

/// 生成的奖励物品
struct GeneratedRewardItem {
    let itemId: UUID
    let itemName: String
    let quantity: Int
    let quality: String?
    let rarity: String

    // AI 生成相关字段
    let isAIGenerated: Bool
    let aiStory: String?
    let aiBonusEffect: String?

    /// 便利初始化器（默认值保持向后兼容）
    init(
        itemId: UUID,
        itemName: String,
        quantity: Int,
        quality: String?,
        rarity: String,
        isAIGenerated: Bool = false,
        aiStory: String? = nil,
        aiBonusEffect: String? = nil
    ) {
        self.itemId = itemId
        self.itemName = itemName
        self.quantity = quantity
        self.quality = quality
        self.rarity = rarity
        self.isAIGenerated = isAIGenerated
        self.aiStory = aiStory
        self.aiBonusEffect = aiBonusEffect
    }
}

// MARK: - RewardGenerator

/// 奖励生成器
/// 根据行走距离生成探索奖励
struct RewardGenerator {

    // MARK: - 距离阈值

    /// 最小奖励距离（米）
    static let minimumDistance: Double = 200

    /// 铜级距离阈值
    static let bronzeThreshold: Double = 200

    /// 银级距离阈值
    static let silverThreshold: Double = 500

    /// 金级距离阈值
    static let goldThreshold: Double = 1000

    /// 钻石级距离阈值
    static let diamondThreshold: Double = 2000

    // MARK: - Public Methods

    /// 根据距离计算奖励等级
    /// - Parameter distance: 行走距离（米）
    /// - Returns: 奖励等级
    static func calculateTier(distance: Double) -> RewardTier {
        switch distance {
        case 0..<bronzeThreshold:
            return .none
        case bronzeThreshold..<silverThreshold:
            return .bronze
        case silverThreshold..<goldThreshold:
            return .silver
        case goldThreshold..<diamondThreshold:
            return .gold
        default:
            return .diamond
        }
    }

    /// 生成奖励物品
    /// - Parameters:
    ///   - distance: 行走距离（米）
    ///   - inventoryManager: 背包管理器（用于获取物品定义）
    /// - Returns: 奖励物品列表
    static func generateRewards(distance: Double, inventoryManager: InventoryManager) -> [GeneratedRewardItem] {
        let tier = calculateTier(distance: distance)

        print("[RewardGenerator] 📊 距离: \(String(format: "%.0f", distance))m，等级: \(tier.displayName)")

        guard tier != .none else {
            print("[RewardGenerator] ⚠️ 未达到最低奖励距离，不生成奖励")
            return []
        }

        var rewards: [GeneratedRewardItem] = []
        let itemCount = tier.itemCount

        // 获取物品池
        let commonItems = inventoryManager.getItemDefinitions(byRarity: "common")
        let rareItems = inventoryManager.getItemDefinitions(byRarity: "uncommon") +
                        inventoryManager.getItemDefinitions(byRarity: "rare")
        let epicItems = inventoryManager.getItemDefinitions(byRarity: "epic") +
                        inventoryManager.getItemDefinitions(byRarity: "legendary")

        print("[RewardGenerator] 📦 物品池: common=\(commonItems.count), rare=\(rareItems.count), epic=\(epicItems.count)")

        // 检查物品定义是否为空
        if commonItems.isEmpty && rareItems.isEmpty && epicItems.isEmpty {
            print("[RewardGenerator] ❌ 物品定义为空！请确保先调用 InventoryManager.loadItemDefinitions()")
            return []
        }

        // 生成物品
        for _ in 0..<itemCount {
            let roll = Double.random(in: 0...1)
            var selectedItem: DBItemDefinition?
            var selectedRarity: String = "common"

            if roll < tier.epicProbability && !epicItems.isEmpty {
                // 史诗物品
                selectedItem = epicItems.randomElement()
                selectedRarity = selectedItem?.rarity ?? "epic"
            } else if roll < tier.epicProbability + tier.rareProbability && !rareItems.isEmpty {
                // 稀有物品
                selectedItem = rareItems.randomElement()
                selectedRarity = selectedItem?.rarity ?? "rare"
            } else if !commonItems.isEmpty {
                // 普通物品
                selectedItem = commonItems.randomElement()
                selectedRarity = "common"
            }

            if let item = selectedItem {
                // 决定品质
                let quality: String? = item.hasQuality ? randomQuality(tier: tier) : nil

                // 合并相同物品
                if let existingIndex = rewards.firstIndex(where: {
                    $0.itemId == item.id && $0.quality == quality
                }) {
                    // 增加数量
                    let existing = rewards[existingIndex]
                    rewards[existingIndex] = GeneratedRewardItem(
                        itemId: existing.itemId,
                        itemName: existing.itemName,
                        quantity: existing.quantity + 1,
                        quality: existing.quality,
                        rarity: existing.rarity
                    )
                } else {
                    // 添加新物品
                    rewards.append(GeneratedRewardItem(
                        itemId: item.id,
                        itemName: item.name,
                        quantity: 1,
                        quality: quality,
                        rarity: selectedRarity
                    ))
                }
            }
        }

        // 按稀有度排序（稀有的在前）
        rewards.sort { item1, item2 in
            rarityOrder(item1.rarity) > rarityOrder(item2.rarity)
        }

        return rewards
    }

    // MARK: - Private Methods

    /// 随机生成品质
    private static func randomQuality(tier: RewardTier) -> String {
        let roll = Double.random(in: 0...1)

        switch tier {
        case .none:
            return "normal"
        case .bronze:
            // 铜级：60% normal, 30% worn, 10% broken
            if roll < 0.10 { return "broken" }
            if roll < 0.40 { return "worn" }
            return "normal"
        case .silver:
            // 银级：50% normal, 30% good, 20% worn
            if roll < 0.20 { return "worn" }
            if roll < 0.50 { return "normal" }
            return "good"
        case .gold:
            // 金级：40% good, 40% normal, 20% pristine
            if roll < 0.20 { return "pristine" }
            if roll < 0.60 { return "good" }
            return "normal"
        case .diamond:
            // 钻石级：40% pristine, 40% good, 20% normal
            if roll < 0.40 { return "pristine" }
            if roll < 0.80 { return "good" }
            return "normal"
        }
    }

    /// 稀有度排序值
    private static func rarityOrder(_ rarity: String) -> Int {
        switch rarity {
        case "legendary": return 5
        case "epic": return 4
        case "rare": return 3
        case "uncommon": return 2
        case "common": return 1
        default: return 0
        }
    }
}
