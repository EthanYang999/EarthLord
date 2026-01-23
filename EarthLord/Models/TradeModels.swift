//
//  TradeModels.swift
//  EarthLord
//
//  Created on 2025/1/23.
//
//  交易系统数据模型
//  支持多物品交易的数据结构
//

import Foundation

// MARK: - 交易状态枚举

/// 交易挂单状态
enum TradeOfferStatus: String, Codable, CaseIterable {
    case active = "active"           // 活跃中，可接受
    case completed = "completed"     // 已完成
    case cancelled = "cancelled"     // 已取消
    case expired = "expired"         // 已过期

    /// 状态显示名称
    var displayName: String {
        switch self {
        case .active: return "挂单中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        case .expired: return "已过期"
        }
    }

    /// 状态颜色名称
    var colorName: String {
        switch self {
        case .active: return "success"
        case .completed: return "info"
        case .cancelled: return "textMuted"
        case .expired: return "warning"
        }
    }
}

// MARK: - 挂单时长选项

/// 挂单时长选项
enum TradeOfferDuration: Int, CaseIterable {
    case oneHour = 1
    case sixHours = 6
    case twelveHours = 12
    case oneDay = 24
    case threeDays = 72
    case oneWeek = 168

    var displayName: String {
        switch self {
        case .oneHour: return "1 小时"
        case .sixHours: return "6 小时"
        case .twelveHours: return "12 小时"
        case .oneDay: return "1 天"
        case .threeDays: return "3 天"
        case .oneWeek: return "1 周"
        }
    }

    /// 计算过期时间
    func expiresAt(from date: Date = Date()) -> Date {
        return date.addingTimeInterval(TimeInterval(rawValue * 3600))
    }
}

// MARK: - 交易物品

/// 交易物品（用于 offering_items 和 requesting_items 数组）
struct TradeItem: Codable, Identifiable, Equatable {
    let itemId: UUID
    let quantity: Int
    let quality: String?

    var id: UUID { itemId }

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case quantity
        case quality
    }

    init(itemId: UUID, quantity: Int, quality: String? = nil) {
        self.itemId = itemId
        self.quantity = quantity
        self.quality = quality
    }
}

/// 交易物品（带名称，用于历史记录）
struct TradeItemWithName: Codable, Identifiable, Equatable {
    let itemId: UUID
    let itemName: String
    let quantity: Int
    let quality: String?

    var id: UUID { itemId }

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case itemName = "item_name"
        case quantity
        case quality
    }
}

/// 交换物品详情（用于 trade_history.items_exchanged）
struct ItemsExchanged: Codable {
    let sellerGave: [TradeItemWithName]
    let buyerGave: [TradeItemWithName]

    enum CodingKeys: String, CodingKey {
        case sellerGave = "seller_gave"
        case buyerGave = "buyer_gave"
    }
}

// MARK: - 交易挂单（数据库模型）

/// 交易挂单记录
struct DBTradeOffer: Codable, Identifiable {
    let id: UUID
    let ownerId: UUID

    // 交易内容
    let offeringItems: [TradeItem]
    let requestingItems: [TradeItem]

    // 挂单信息
    let message: String?
    let status: TradeOfferStatus

    // 时间戳
    let expiresAt: Date
    let createdAt: Date
    let updatedAt: Date

    // 完成信息
    let completedByUserId: UUID?
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case offeringItems = "offering_items"
        case requestingItems = "requesting_items"
        case message
        case status
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case completedByUserId = "completed_by_user_id"
        case completedAt = "completed_at"
    }

    // MARK: - 计算属性

    /// 是否已过期
    var isExpired: Bool {
        return Date() > expiresAt
    }

    /// 是否可接受（活跃且未过期）
    var isAcceptable: Bool {
        return status == .active && !isExpired
    }

    /// 剩余时间（秒）
    var remainingTime: TimeInterval {
        return max(0, expiresAt.timeIntervalSinceNow)
    }

    /// 格式化剩余时间
    var formattedRemainingTime: String {
        let seconds = Int(remainingTime)
        if seconds <= 0 {
            return "已过期"
        } else if seconds < 60 {
            return "\(seconds)秒"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)分钟"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return minutes > 0 ? "\(hours)小时\(minutes)分" : "\(hours)小时"
        } else {
            let days = seconds / 86400
            let hours = (seconds % 86400) / 3600
            return hours > 0 ? "\(days)天\(hours)小时" : "\(days)天"
        }
    }

    /// 提供物品数量
    var offeringItemCount: Int {
        return offeringItems.reduce(0) { $0 + $1.quantity }
    }

    /// 需求物品数量
    var requestingItemCount: Int {
        return requestingItems.reduce(0) { $0 + $1.quantity }
    }
}

// MARK: - 交易历史（数据库模型）

/// 交易历史记录
struct DBTradeHistory: Codable, Identifiable {
    let id: UUID
    let offerId: UUID?

    // 交易双方
    let sellerId: UUID
    let buyerId: UUID

    // 交换内容
    let itemsExchanged: ItemsExchanged

    // 评价信息
    let sellerRating: Int?
    let sellerComment: String?
    let sellerRatedAt: Date?

    let buyerRating: Int?
    let buyerComment: String?
    let buyerRatedAt: Date?

    // 时间戳
    let completedAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case offerId = "offer_id"
        case sellerId = "seller_id"
        case buyerId = "buyer_id"
        case itemsExchanged = "items_exchanged"
        case sellerRating = "seller_rating"
        case sellerComment = "seller_comment"
        case sellerRatedAt = "seller_rated_at"
        case buyerRating = "buyer_rating"
        case buyerComment = "buyer_comment"
        case buyerRatedAt = "buyer_rated_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
    }

    // MARK: - 计算属性

    /// 检查当前用户是否是卖家
    func isSeller(userId: UUID) -> Bool {
        return sellerId == userId
    }

    /// 获取当前用户的交易对象ID
    func counterpartyId(for userId: UUID) -> UUID {
        return isSeller(userId: userId) ? buyerId : sellerId
    }

    /// 当前用户是否已评价
    func hasRated(userId: UUID) -> Bool {
        if isSeller(userId: userId) {
            return sellerRating != nil
        } else {
            return buyerRating != nil
        }
    }

    /// 对方是否已评价
    func hasCounterpartyRated(userId: UUID) -> Bool {
        if isSeller(userId: userId) {
            return buyerRating != nil
        } else {
            return sellerRating != nil
        }
    }

    /// 获取当前用户给出的物品
    func itemsGiven(by userId: UUID) -> [TradeItemWithName] {
        return isSeller(userId: userId) ? itemsExchanged.sellerGave : itemsExchanged.buyerGave
    }

    /// 获取当前用户收到的物品
    func itemsReceived(by userId: UUID) -> [TradeItemWithName] {
        return isSeller(userId: userId) ? itemsExchanged.buyerGave : itemsExchanged.sellerGave
    }
}

// MARK: - 请求模型

/// 创建交易挂单请求
struct CreateTradeOfferRequest: Codable {
    let ownerId: UUID
    let offeringItems: [TradeItem]
    let requestingItems: [TradeItem]
    let message: String?
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case ownerId = "owner_id"
        case offeringItems = "offering_items"
        case requestingItems = "requesting_items"
        case message
        case expiresAt = "expires_at"
    }
}

/// 更新挂单状态请求
struct UpdateTradeOfferRequest: Codable {
    let status: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case status
        case updatedAt = "updated_at"
    }

    /// 取消挂单
    static func cancel() -> UpdateTradeOfferRequest {
        return UpdateTradeOfferRequest(
            status: TradeOfferStatus.cancelled.rawValue,
            updatedAt: Date()
        )
    }
}

/// 提交评价请求（卖家评价买家）
struct SellerRatingRequest: Codable {
    let sellerRating: Int
    let sellerComment: String?
    let sellerRatedAt: Date

    enum CodingKeys: String, CodingKey {
        case sellerRating = "seller_rating"
        case sellerComment = "seller_comment"
        case sellerRatedAt = "seller_rated_at"
    }
}

/// 提交评价请求（买家评价卖家）
struct BuyerRatingRequest: Codable {
    let buyerRating: Int
    let buyerComment: String?
    let buyerRatedAt: Date

    enum CodingKeys: String, CodingKey {
        case buyerRating = "buyer_rating"
        case buyerComment = "buyer_comment"
        case buyerRatedAt = "buyer_rated_at"
    }
}

// MARK: - 响应模型

/// 接受交易响应
struct AcceptTradeResponse: Codable {
    let success: Bool
    let historyId: UUID?
    let error: String?
    let message: String?
    let details: String?

    enum CodingKeys: String, CodingKey {
        case success
        case historyId = "history_id"
        case error
        case message
        case details
    }
}

// MARK: - 交易错误枚举

/// 交易错误
enum TradeError: LocalizedError {
    case notAuthenticated              // 用户未登录
    case insufficientItems(String)     // 物品数量不足（带详情）
    case itemNotFound                  // 物品不存在
    case offerNotFound                 // 挂单不存在
    case offerNotActive                // 挂单非活跃状态
    case offerExpired                  // 挂单已过期
    case cannotAcceptOwnOffer          // 不能接受自己的挂单
    case itemTypeMismatch              // 物品类型不匹配
    case qualityNotMet                 // 品质不符合要求
    case alreadyRated                  // 已经评价过
    case invalidRating                 // 无效的评分（1-5）
    case invalidDuration               // 无效的挂单时长
    case emptyOffer                    // 空挂单（没有提供或需求物品）
    case databaseError(String)         // 数据库错误
    case networkError(String)          // 网络错误

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .insufficientItems(let details):
            return details.isEmpty ? "物品数量不足" : details
        case .itemNotFound:
            return "物品不存在"
        case .offerNotFound:
            return "挂单不存在"
        case .offerNotActive:
            return "该挂单已不可接受"
        case .offerExpired:
            return "挂单已过期"
        case .cannotAcceptOwnOffer:
            return "不能接受自己的挂单"
        case .itemTypeMismatch:
            return "物品类型不匹配"
        case .qualityNotMet:
            return "物品品质不符合要求"
        case .alreadyRated:
            return "您已经评价过此次交易"
        case .invalidRating:
            return "评分必须在 1-5 之间"
        case .invalidDuration:
            return "挂单时长必须在 1-168 小时之间"
        case .emptyOffer:
            return "请至少选择一个提供物品和一个需求物品"
        case .databaseError(let message):
            return "数据库错误: \(message)"
        case .networkError(let message):
            return "网络错误: \(message)"
        }
    }
}

// MARK: - 辅助扩展

extension Array where Element == TradeItem {
    /// 计算物品总数量
    var totalQuantity: Int {
        return reduce(0) { $0 + $1.quantity }
    }

    /// 获取指定物品的数量
    func quantity(for itemId: UUID) -> Int {
        return filter { $0.itemId == itemId }.reduce(0) { $0 + $1.quantity }
    }
}
