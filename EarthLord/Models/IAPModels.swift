//
//  IAPModels.swift
//  EarthLord
//
//  内购系统数据模型
//

import Foundation

// MARK: - 物资包等级

enum SupplyPackTier: Int, CaseIterable, Codable {
    case survivor = 1   // 幸存者补给包 ¥6
    case explorer = 2   // 探索者物资包 ¥18
    case lord = 3       // 领主物资包 ¥30
    case overlord = 4   // 末日霸主包 ¥68

    var displayName: String {
        switch self {
        case .survivor: return String(localized: "幸存者补给包")
        case .explorer: return String(localized: "探索者物资包")
        case .lord: return String(localized: "领主物资包")
        case .overlord: return String(localized: "末日霸主包")
        }
    }

    var productId: String {
        switch self {
        case .survivor: return "com.earthlord.supply.survivor"
        case .explorer: return "com.earthlord.supply.explorer"
        case .lord: return "com.earthlord.supply.lord"
        case .overlord: return "com.earthlord.supply.overlord"
        }
    }

    var icon: String {
        switch self {
        case .survivor: return "gift"
        case .explorer: return "shippingbox"
        case .lord: return "cube.box"
        case .overlord: return "crown"
        }
    }

    var tierColor: String {
        switch self {
        case .survivor: return "common"      // 普通 - 灰色
        case .explorer: return "uncommon"    // 少见 - 绿色
        case .lord: return "rare"            // 稀有 - 蓝色
        case .overlord: return "legendary"   // 传说 - 金色
        }
    }
}

// MARK: - 物资包定义（数据库模型）

struct DBSupplyPackDefinition: Codable, Identifiable {
    let id: UUID
    let productId: String
    let name: String
    let description: String?
    let icon: String?
    let tier: Int
    let priceCny: Double
    let items: [SupplyPackItem]
    let isActive: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case productId = "product_id"
        case name
        case description
        case icon
        case tier
        case priceCny = "price_cny"
        case items
        case isActive = "is_active"
        case createdAt = "created_at"
    }

    var tierEnum: SupplyPackTier? {
        return SupplyPackTier(rawValue: tier)
    }
}

// MARK: - 物资包内容物品

struct SupplyPackItem: Codable, Identifiable {
    let itemName: String
    let quantity: Int

    var id: String { itemName }

    enum CodingKeys: String, CodingKey {
        case itemName = "item_name"
        case quantity
    }
}

// MARK: - 购买记录（数据库模型）

struct DBPurchaseRecord: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let productId: String
    let transactionId: String
    let purchaseDate: Date
    let environment: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case productId = "product_id"
        case transactionId = "transaction_id"
        case purchaseDate = "purchase_date"
        case environment
        case createdAt = "created_at"
    }
}

// MARK: - 邮箱物品（数据库模型）

struct DBMailboxItem: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let sourceType: String
    let sourceId: UUID?
    let title: String
    let items: [MailboxReward]
    let isClaimed: Bool
    let claimedAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sourceType = "source_type"
        case sourceId = "source_id"
        case title
        case items
        case isClaimed = "is_claimed"
        case claimedAt = "claimed_at"
        case createdAt = "created_at"
    }

    var sourceTypeEnum: MailboxSourceType {
        return MailboxSourceType(rawValue: sourceType) ?? .system
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

// MARK: - 邮箱物品来源类型

enum MailboxSourceType: String, Codable {
    case purchase = "purchase"   // 内购
    case reward = "reward"       // 奖励
    case system = "system"       // 系统发放
    case trade = "trade"         // 交易
    case event = "event"         // 活动

    var displayName: String {
        switch self {
        case .purchase: return String(localized: "商城购买")
        case .reward: return String(localized: "任务奖励")
        case .system: return String(localized: "系统发放")
        case .trade: return String(localized: "交易获得")
        case .event: return String(localized: "活动奖励")
        }
    }

    var icon: String {
        switch self {
        case .purchase: return "cart.fill"
        case .reward: return "star.fill"
        case .system: return "envelope.fill"
        case .trade: return "arrow.triangle.2.circlepath"
        case .event: return "gift.fill"
        }
    }
}

// MARK: - 邮箱奖励物品

struct MailboxReward: Codable, Identifiable {
    let itemName: String
    let quantity: Int
    let quality: String?

    var id: String { "\(itemName)_\(quality ?? "normal")" }

    enum CodingKeys: String, CodingKey {
        case itemName = "item_name"
        case quantity
        case quality
    }

    init(itemName: String, quantity: Int, quality: String? = nil) {
        self.itemName = itemName
        self.quantity = quantity
        self.quality = quality
    }
}

// MARK: - 内购错误

enum IAPError: LocalizedError {
    case notAuthenticated
    case productNotFound
    case purchaseFailed(String)
    case purchaseCancelled
    case purchasePending
    case verificationFailed
    case networkError
    case databaseError(String)
    case mailboxEmpty
    case itemAlreadyClaimed
    case insufficientCapacity
    case unknownError

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "请先登录账户")
        case .productNotFound:
            return String(localized: "未找到该商品")
        case .purchaseFailed(let message):
            return String(localized: "购买失败: \(message)")
        case .purchaseCancelled:
            return String(localized: "购买已取消")
        case .purchasePending:
            return String(localized: "购买正在处理中")
        case .verificationFailed:
            return String(localized: "交易验证失败")
        case .networkError:
            return String(localized: "网络连接失败")
        case .databaseError(let message):
            return String(localized: "数据库错误: \(message)")
        case .mailboxEmpty:
            return String(localized: "邮箱为空")
        case .itemAlreadyClaimed:
            return String(localized: "物品已被领取")
        case .insufficientCapacity:
            return String(localized: "背包容量不足")
        case .unknownError:
            return String(localized: "发生未知错误")
        }
    }
}

// MARK: - 购买状态

enum PurchaseState: Equatable {
    case idle
    case loading
    case purchasing(String)  // productId
    case success
    case failed(String)
}
