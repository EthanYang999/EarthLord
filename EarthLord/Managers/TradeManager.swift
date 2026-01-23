//
//  TradeManager.swift
//  EarthLord
//
//  Created on 2025/1/23.
//
//  交易管理器
//  负责交易挂单的创建、查询、接受、取消及评价
//  支持多物品交易
//

import Foundation
import Combine
import Supabase

/// 交易管理器
/// 负责管理玩家间的物品交易
@MainActor
final class TradeManager: ObservableObject {

    // MARK: - Singleton

    static let shared = TradeManager()

    // MARK: - Published Properties

    /// 市场挂单列表（活跃的，非自己的）
    @Published private(set) var marketOffers: [DBTradeOffer] = []

    /// 我的挂单列表
    @Published private(set) var myOffers: [DBTradeOffer] = []

    /// 我的交易历史
    @Published private(set) var tradeHistory: [DBTradeHistory] = []

    /// 是否正在加载
    @Published private(set) var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let client = supabase

    /// 刷新计时器（用于更新剩余时间显示）
    private var refreshTimer: Timer?

    // MARK: - Initialization

    private init() {
        startRefreshTimer()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Refresh Timer

    /// 启动刷新计时器（每分钟刷新一次以更新剩余时间）
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            guard let manager = self else { return }
            Task { @MainActor in
                // 触发 UI 刷新以更新剩余时间显示
                manager.objectWillChange.send()

                // 过滤掉已过期的市场挂单
                manager.marketOffers = manager.marketOffers.filter { !$0.isExpired }
            }
        }
    }

    // MARK: - Load Methods

    /// 加载市场挂单（活跃的、未过期的、非自己的）
    func loadMarketOffers() async {
        guard let userId = try? await client.auth.session.user.id else {
            print("[TradeManager] ⚠️ 用户未登录")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let offers: [DBTradeOffer] = try await client
                .from("trade_offers")
                .select()
                .eq("status", value: "active")
                .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
                .neq("owner_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            self.marketOffers = offers
            print("[TradeManager] ✅ 加载了 \(offers.count) 个市场挂单")

        } catch {
            print("[TradeManager] ❌ 加载市场挂单失败: \(error)")
            self.errorMessage = "加载市场挂单失败"
        }
    }

    /// 加载我的挂单
    func loadMyOffers() async {
        guard let userId = try? await client.auth.session.user.id else {
            print("[TradeManager] ⚠️ 用户未登录")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let offers: [DBTradeOffer] = try await client
                .from("trade_offers")
                .select()
                .eq("owner_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            self.myOffers = offers
            print("[TradeManager] ✅ 加载了 \(offers.count) 个我的挂单")

        } catch {
            print("[TradeManager] ❌ 加载我的挂单失败: \(error)")
            self.errorMessage = "加载我的挂单失败"
        }
    }

    /// 加载交易历史
    func loadTradeHistory() async {
        guard let userId = try? await client.auth.session.user.id else {
            print("[TradeManager] ⚠️ 用户未登录")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let history: [DBTradeHistory] = try await client
                .from("trade_history")
                .select()
                .or("seller_id.eq.\(userId.uuidString),buyer_id.eq.\(userId.uuidString)")
                .order("completed_at", ascending: false)
                .limit(100)
                .execute()
                .value

            self.tradeHistory = history
            print("[TradeManager] ✅ 加载了 \(history.count) 条交易历史")

        } catch {
            print("[TradeManager] ❌ 加载交易历史失败: \(error)")
            self.errorMessage = "加载交易历史失败"
        }
    }

    // MARK: - Create Offer

    /// 创建交易挂单（支持多物品）
    /// - Parameters:
    ///   - offeringItems: 要提供的物品列表（包含背包物品ID、数量）
    ///   - requestingItems: 需要的物品列表（物品定义ID、数量、品质要求）
    ///   - message: 留言
    ///   - duration: 挂单时长
    /// - Returns: 创建的挂单，失败抛出错误
    func createOffer(
        offeringItems: [TradeItem],
        requestingItems: [TradeItem],
        message: String? = nil,
        duration: TradeOfferDuration = .oneDay
    ) async throws -> DBTradeOffer {

        // 1. 验证参数
        guard !offeringItems.isEmpty else {
            throw TradeError.emptyOffer
        }
        guard !requestingItems.isEmpty else {
            throw TradeError.emptyOffer
        }

        // 2. 验证用户登录
        guard let userId = try? await client.auth.session.user.id else {
            throw TradeError.notAuthenticated
        }

        // 3. 验证并锁定物品（从背包扣除）
        let inventoryManager = InventoryManager.shared
        var lockedItems: [(itemId: UUID, quantity: Int, quality: String?)] = []

        for item in offeringItems {
            // 查找背包中的物品
            let matchingItems = inventoryManager.inventoryItems.filter { $0.itemId == item.itemId }

            // 计算拥有的总数量
            let ownedQuantity = matchingItems.reduce(0) { $0 + $1.quantity }

            if ownedQuantity < item.quantity {
                // 回滚已锁定的物品
                await rollbackItems(lockedItems)

                // 获取物品名称
                let itemName = inventoryManager.getItemDefinition(by: item.itemId)?.name ?? "未知物品"
                throw TradeError.insufficientItems("\(itemName) 不足，需要 \(item.quantity) 个，拥有 \(ownedQuantity) 个")
            }

            // 扣除物品（可能需要从多个堆叠中扣除）
            var remaining = item.quantity
            for invItem in matchingItems {
                if remaining <= 0 { break }

                let removeQty = min(invItem.quantity, remaining)
                let success = await inventoryManager.removeItem(
                    inventoryItemId: invItem.id,
                    quantity: removeQty
                )

                if success {
                    lockedItems.append((itemId: item.itemId, quantity: removeQty, quality: invItem.quality))
                    remaining -= removeQty
                } else {
                    // 回滚
                    await rollbackItems(lockedItems)
                    throw TradeError.databaseError("扣除物品失败")
                }
            }
        }

        // 4. 创建挂单
        let request = CreateTradeOfferRequest(
            ownerId: userId,
            offeringItems: offeringItems,
            requestingItems: requestingItems,
            message: message,
            expiresAt: duration.expiresAt()
        )

        do {
            let response: [DBTradeOffer] = try await client
                .from("trade_offers")
                .insert(request)
                .select()
                .execute()
                .value

            guard let offer = response.first else {
                await rollbackItems(lockedItems)
                throw TradeError.databaseError("创建挂单失败")
            }

            print("[TradeManager] ✅ 创建挂单成功: \(offer.id)，包含 \(offeringItems.count) 种提供物品")

            // 刷新我的挂单列表
            await loadMyOffers()

            return offer

        } catch let error as TradeError {
            await rollbackItems(lockedItems)
            throw error
        } catch {
            await rollbackItems(lockedItems)
            throw TradeError.databaseError(error.localizedDescription)
        }
    }

    /// 回滚物品（创建挂单失败时返还物品）
    private func rollbackItems(_ items: [(itemId: UUID, quantity: Int, quality: String?)]) async {
        let inventoryManager = InventoryManager.shared
        for item in items {
            _ = await inventoryManager.addItem(
                itemId: item.itemId,
                quantity: item.quantity,
                quality: item.quality
            )
        }
        if !items.isEmpty {
            print("[TradeManager] ⚠️ 已回滚 \(items.count) 个物品")
        }
    }

    // MARK: - Cancel Offer

    /// 取消挂单（物品返还）
    /// - Parameter offerId: 挂单 ID
    func cancelOffer(offerId: UUID) async throws {
        // 1. 验证用户登录
        guard let userId = try? await client.auth.session.user.id else {
            throw TradeError.notAuthenticated
        }

        // 2. 查找挂单
        guard let offer = myOffers.first(where: { $0.id == offerId }) else {
            throw TradeError.offerNotFound
        }

        // 3. 验证是自己的挂单
        guard offer.ownerId == userId else {
            throw TradeError.offerNotFound
        }

        // 4. 验证挂单状态
        guard offer.status == .active else {
            throw TradeError.offerNotActive
        }

        // 5. 更新挂单状态
        let updateRequest = UpdateTradeOfferRequest.cancel()

        do {
            try await client
                .from("trade_offers")
                .update(updateRequest)
                .eq("id", value: offerId.uuidString)
                .execute()

            // 6. 返还所有物品到背包
            let inventoryManager = InventoryManager.shared
            var returnedCount = 0

            for item in offer.offeringItems {
                let success = await inventoryManager.addItem(
                    itemId: item.itemId,
                    quantity: item.quantity,
                    quality: item.quality
                )
                if success {
                    returnedCount += 1
                }
            }

            print("[TradeManager] ✅ 取消挂单成功，返还了 \(returnedCount) 种物品")

            // 7. 刷新列表
            await loadMyOffers()

        } catch {
            throw TradeError.databaseError(error.localizedDescription)
        }
    }

    // MARK: - Accept Offer

    /// 接受交易挂单
    /// - Parameter offerId: 挂单 ID
    /// - Returns: 交易历史记录
    func acceptOffer(offerId: UUID) async throws -> DBTradeHistory {
        // 1. 验证用户登录
        guard let _ = try? await client.auth.session.user.id else {
            throw TradeError.notAuthenticated
        }

        // 2. 调用安全的存储过程
        do {
            let response: AcceptTradeResponse = try await client
                .rpc("accept_trade_offer", params: [
                    "p_offer_id": offerId.uuidString
                ])
                .execute()
                .value

            if response.success, let historyId = response.historyId {
                print("[TradeManager] ✅ 交易完成: \(historyId)")

                // 刷新数据
                await loadMarketOffers()
                await loadTradeHistory()
                await InventoryManager.shared.loadInventory()

                // 获取交易历史详情
                let history: [DBTradeHistory] = try await client
                    .from("trade_history")
                    .select()
                    .eq("id", value: historyId.uuidString)
                    .execute()
                    .value

                guard let result = history.first else {
                    throw TradeError.databaseError("获取交易详情失败")
                }

                return result

            } else {
                // 解析错误
                let errorCode = response.error ?? "unknown"
                let details = response.details ?? ""
                throw mapAcceptTradeError(errorCode, details: details)
            }

        } catch let error as TradeError {
            throw error
        } catch {
            throw TradeError.databaseError(error.localizedDescription)
        }
    }

    /// 映射接受交易错误码
    private func mapAcceptTradeError(_ code: String, details: String = "") -> TradeError {
        switch code {
        case "not_authenticated":
            return .notAuthenticated
        case "offer_not_found":
            return .offerNotFound
        case "offer_not_active":
            return .offerNotActive
        case "offer_expired":
            return .offerExpired
        case "cannot_accept_own_offer":
            return .cannotAcceptOwnOffer
        case "insufficient_items":
            return .insufficientItems(details)
        case "item_type_mismatch":
            return .itemTypeMismatch
        case "quality_not_met":
            return .qualityNotMet
        default:
            return .databaseError(details.isEmpty ? code : details)
        }
    }

    // MARK: - Rating

    /// 提交交易评价
    /// - Parameters:
    ///   - historyId: 交易历史 ID
    ///   - rating: 评分（1-5）
    ///   - comment: 评论（可选）
    func submitRating(historyId: UUID, rating: Int, comment: String?) async throws {
        // 1. 验证评分范围
        guard rating >= 1 && rating <= 5 else {
            throw TradeError.invalidRating
        }

        // 2. 验证用户登录
        guard let userId = try? await client.auth.session.user.id else {
            throw TradeError.notAuthenticated
        }

        // 3. 查找交易历史
        guard let history = tradeHistory.first(where: { $0.id == historyId }) else {
            throw TradeError.offerNotFound
        }

        // 4. 检查是否已评价
        if history.hasRated(userId: userId) {
            throw TradeError.alreadyRated
        }

        // 5. 确定是卖家还是买家，使用对应的请求模型
        let isSeller = history.isSeller(userId: userId)
        let now = Date()

        do {
            if isSeller {
                let request = SellerRatingRequest(
                    sellerRating: rating,
                    sellerComment: comment,
                    sellerRatedAt: now
                )

                try await client
                    .from("trade_history")
                    .update(request)
                    .eq("id", value: historyId.uuidString)
                    .execute()
            } else {
                let request = BuyerRatingRequest(
                    buyerRating: rating,
                    buyerComment: comment,
                    buyerRatedAt: now
                )

                try await client
                    .from("trade_history")
                    .update(request)
                    .eq("id", value: historyId.uuidString)
                    .execute()
            }

            print("[TradeManager] ✅ 评价提交成功")

            // 刷新数据
            await loadTradeHistory()

        } catch {
            throw TradeError.databaseError(error.localizedDescription)
        }
    }

    // MARK: - Utility Methods

    /// 获取挂单详情
    /// - Parameter offerId: 挂单 ID
    /// - Returns: 挂单详情
    func getOfferDetail(offerId: UUID) async -> DBTradeOffer? {
        do {
            let offers: [DBTradeOffer] = try await client
                .from("trade_offers")
                .select()
                .eq("id", value: offerId.uuidString)
                .execute()
                .value

            return offers.first
        } catch {
            print("[TradeManager] ❌ 获取挂单详情失败: \(error)")
            return nil
        }
    }

    /// 刷新所有数据
    func refreshAll() async {
        await loadMarketOffers()
        await loadMyOffers()
        await loadTradeHistory()
    }

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    /// 检查用户是否拥有足够的物品来接受某个挂单
    /// - Parameter offer: 挂单
    /// - Returns: (canAccept: Bool, missingItems: [(name: String, need: Int, have: Int)])
    func checkCanAcceptOffer(_ offer: DBTradeOffer) -> (canAccept: Bool, missingItems: [(name: String, need: Int, have: Int)]) {
        let inventoryManager = InventoryManager.shared
        var missingItems: [(name: String, need: Int, have: Int)] = []

        for item in offer.requestingItems {
            // 计算拥有的数量
            let ownedQuantity = inventoryManager.inventoryItems
                .filter { $0.itemId == item.itemId }
                .reduce(0) { $0 + $1.quantity }

            if ownedQuantity < item.quantity {
                let itemName = inventoryManager.getItemDefinition(by: item.itemId)?.name ?? "未知物品"
                missingItems.append((name: itemName, need: item.quantity, have: ownedQuantity))
            }
        }

        return (missingItems.isEmpty, missingItems)
    }

    /// 搜索包含特定物品的挂单
    /// - Parameter itemId: 物品定义 ID
    /// - Returns: 包含该物品的市场挂单
    func searchOffersWithItem(_ itemId: UUID) -> [DBTradeOffer] {
        return marketOffers.filter { offer in
            offer.offeringItems.contains { $0.itemId == itemId }
        }
    }

    /// 搜索需求特定物品的挂单
    /// - Parameter itemId: 物品定义 ID
    /// - Returns: 需求该物品的市场挂单
    func searchOffersWantingItem(_ itemId: UUID) -> [DBTradeOffer] {
        return marketOffers.filter { offer in
            offer.requestingItems.contains { $0.itemId == itemId }
        }
    }
}
