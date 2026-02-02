//
//  IAPManager.swift
//  EarthLord
//
//  内购管理器
//  使用 StoreKit 2 实现消耗型内购
//

import Foundation
import StoreKit
import Supabase
import Combine

// MARK: - IAPManager

@MainActor
final class IAPManager: ObservableObject {

    // MARK: - Singleton

    static let shared = IAPManager()

    // MARK: - Published Properties

    /// App Store 产品列表
    @Published private(set) var products: [Product] = []

    /// 物资包定义（从数据库加载）
    @Published private(set) var supplyPacks: [DBSupplyPackDefinition] = []

    /// 邮箱物品列表
    @Published private(set) var mailboxItems: [DBMailboxItem] = []

    /// 未领取邮件数量
    @Published private(set) var unclaimedCount: Int = 0

    /// 购买状态
    @Published var purchaseState: PurchaseState = .idle

    /// 是否正在加载
    @Published private(set) var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let client = supabase
    private var transactionListener: Task<Void, Error>?

    /// 产品 ID 列表
    private let productIds: Set<String> = [
        "com.earthlord.supply.survivor",
        "com.earthlord.supply.explorer",
        "com.earthlord.supply.lord",
        "com.earthlord.supply.overlord"
    ]

    // MARK: - Initialization

    private init() {}

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Transaction Listener

    /// 启动交易监听器（应用启动时调用）
    func startTransactionListener() {
        transactionListener = Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handleTransaction(result)
            }
        }
        print("[IAPManager] 交易监听器已启动")
    }

    /// 处理交易
    private func handleTransaction(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            print("[IAPManager] 收到已验证交易: \(transaction.productID)")

            // 发放物资到邮箱
            await deliverPurchase(productId: transaction.productID, transactionId: String(transaction.id))

            // 完成交易
            await transaction.finish()

        case .unverified(let transaction, let error):
            print("[IAPManager] 交易验证失败: \(transaction.productID), 错误: \(error)")
        }
    }

    // MARK: - Load Products

    /// 从 App Store 加载产品
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(for: productIds)
            self.products = storeProducts.sorted { $0.price < $1.price }
            print("[IAPManager] 加载了 \(products.count) 个产品")
        } catch {
            print("[IAPManager] 加载产品失败: \(error)")
            errorMessage = "加载商品失败"
        }
    }

    /// 从数据库加载物资包定义
    func loadSupplyPacks() async {
        do {
            let packs: [DBSupplyPackDefinition] = try await client
                .from("supply_pack_definitions")
                .select()
                .eq("is_active", value: true)
                .order("tier")
                .execute()
                .value

            self.supplyPacks = packs
            print("[IAPManager] 加载了 \(packs.count) 个物资包定义")
        } catch {
            print("[IAPManager] 加载物资包定义失败: \(error)")
        }
    }

    // MARK: - Purchase

    /// 购买产品
    func purchase(_ product: Product) async -> Result<Void, IAPError> {
        guard let _ = try? await client.auth.session.user.id else {
            return .failure(.notAuthenticated)
        }

        purchaseState = .purchasing(product.id)

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    print("[IAPManager] 购买成功: \(product.id)")

                    // 发放物资到邮箱
                    await deliverPurchase(productId: product.id, transactionId: String(transaction.id))

                    // 完成交易
                    await transaction.finish()

                    purchaseState = .success
                    return .success(())

                case .unverified(_, let error):
                    print("[IAPManager] 交易验证失败: \(error)")
                    purchaseState = .failed("验证失败")
                    return .failure(.verificationFailed)
                }

            case .pending:
                print("[IAPManager] 购买待处理")
                purchaseState = .idle
                return .failure(.purchasePending)

            case .userCancelled:
                print("[IAPManager] 用户取消购买")
                purchaseState = .idle
                return .failure(.purchaseCancelled)

            @unknown default:
                purchaseState = .idle
                return .failure(.unknownError)
            }

        } catch {
            print("[IAPManager] 购买失败: \(error)")
            purchaseState = .failed(error.localizedDescription)
            return .failure(.purchaseFailed(error.localizedDescription))
        }
    }

    // MARK: - Restore Purchases

    /// 恢复购买（同步未完成的交易）
    func restorePurchases() async -> Result<Int, IAPError> {
        guard let _ = try? await client.auth.session.user.id else {
            return .failure(.notAuthenticated)
        }

        isLoading = true
        defer { isLoading = false }

        var restoredCount = 0

        do {
            // 同步所有交易
            try await AppStore.sync()

            // 检查当前的权益
            for await result in Transaction.currentEntitlements {
                switch result {
                case .verified(let transaction):
                    // 消耗型产品通常不需要恢复，但可以记录
                    print("[IAPManager] 发现交易: \(transaction.productID)")
                    restoredCount += 1

                case .unverified:
                    continue
                }
            }

            print("[IAPManager] 恢复完成，找到 \(restoredCount) 个交易")
            return .success(restoredCount)

        } catch {
            print("[IAPManager] 恢复购买失败: \(error)")
            return .failure(.purchaseFailed(error.localizedDescription))
        }
    }

    // MARK: - Deliver Purchase

    /// 发放购买物资到邮箱
    private func deliverPurchase(productId: String, transactionId: String) async {
        guard let userId = try? await client.auth.session.user.id else {
            print("[IAPManager] 发放失败: 用户未登录")
            return
        }

        // 查找物资包定义
        guard let pack = supplyPacks.first(where: { $0.productId == productId }) else {
            print("[IAPManager] 发放失败: 未找到物资包定义 \(productId)")
            // 如果缓存为空，尝试重新加载
            await loadSupplyPacks()
            guard let pack = supplyPacks.first(where: { $0.productId == productId }) else {
                return
            }
            await deliverPurchaseInternal(userId: userId, pack: pack, transactionId: transactionId)
            return
        }

        await deliverPurchaseInternal(userId: userId, pack: pack, transactionId: transactionId)
    }

    private func deliverPurchaseInternal(userId: UUID, pack: DBSupplyPackDefinition, transactionId: String) async {
        do {
            // 1. 记录购买
            let purchaseRecord = InsertPurchaseRecord(
                userId: userId,
                productId: pack.productId,
                transactionId: transactionId,
                purchaseDate: Date(),
                environment: isTestEnvironment() ? "sandbox" : "production"
            )

            try await client
                .from("purchase_records")
                .insert(purchaseRecord)
                .execute()

            print("[IAPManager] 购买记录已保存")

            // 2. 转换物资包物品为邮箱奖励格式
            let rewards = pack.items.map { item in
                MailboxReward(itemName: item.itemName, quantity: item.quantity, quality: nil)
            }

            // 3. 创建邮箱物品
            let mailboxItem = InsertMailboxItem(
                userId: userId,
                sourceType: "purchase",
                sourceId: pack.id,
                title: pack.name,
                items: rewards
            )

            try await client
                .from("mailbox_items")
                .insert(mailboxItem)
                .execute()

            print("[IAPManager] 物资已发放到邮箱: \(pack.name)")

            // 4. 刷新邮箱
            await loadMailbox()

        } catch {
            print("[IAPManager] 发放购买物资失败: \(error)")
        }
    }

    /// 判断是否为测试环境
    private func isTestEnvironment() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - Mailbox

    /// 加载邮箱物品
    func loadMailbox() async {
        guard let userId = try? await client.auth.session.user.id else {
            print("[IAPManager] 加载邮箱失败: 用户未登录")
            return
        }

        do {
            let items: [DBMailboxItem] = try await client
                .from("mailbox_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            self.mailboxItems = items
            self.unclaimedCount = items.filter { !$0.isClaimed }.count

            print("[IAPManager] 加载了 \(items.count) 个邮箱物品，\(unclaimedCount) 个未领取")
        } catch {
            print("[IAPManager] 加载邮箱失败: \(error)")
            errorMessage = "加载邮箱失败"
        }
    }

    /// 领取邮箱物品
    func claimMailboxItem(_ item: DBMailboxItem) async -> Result<Void, IAPError> {
        guard let _ = try? await client.auth.session.user.id else {
            return .failure(.notAuthenticated)
        }

        if item.isClaimed {
            return .failure(.itemAlreadyClaimed)
        }

        do {
            // 1. 将物品添加到背包
            let inventoryManager = InventoryManager.shared

            // 确保物品定义已加载
            if inventoryManager.itemDefinitions.isEmpty {
                await inventoryManager.loadItemDefinitions()
            }

            for reward in item.items {
                // 通过物品名称查找物品定义
                if let itemDef = inventoryManager.getItemDefinition(byName: reward.itemName) {
                    let success = await inventoryManager.addItem(
                        itemId: itemDef.id,
                        quantity: reward.quantity,
                        quality: reward.quality
                    )
                    if success {
                        print("[IAPManager] 添加物品到背包: \(reward.itemName) x\(reward.quantity)")
                    }
                } else {
                    print("[IAPManager] 未找到物品定义: \(reward.itemName)")
                }
            }

            // 2. 更新邮箱物品状态
            let claimUpdate = UpdateMailboxItemClaim(isClaimed: true, claimedAt: Date())
            try await client
                .from("mailbox_items")
                .update(claimUpdate)
                .eq("id", value: item.id.uuidString)
                .execute()

            print("[IAPManager] 邮箱物品已领取: \(item.title)")

            // 3. 刷新邮箱
            await loadMailbox()

            return .success(())

        } catch {
            print("[IAPManager] 领取邮箱物品失败: \(error)")
            return .failure(.databaseError(error.localizedDescription))
        }
    }

    /// 一键领取所有未领取的邮箱物品
    func claimAllMailboxItems() async -> Result<Int, IAPError> {
        let unclaimedItems = mailboxItems.filter { !$0.isClaimed }

        if unclaimedItems.isEmpty {
            return .failure(.mailboxEmpty)
        }

        var claimedCount = 0
        for item in unclaimedItems {
            let result = await claimMailboxItem(item)
            if case .success = result {
                claimedCount += 1
            }
        }

        return .success(claimedCount)
    }

    // MARK: - Helper Methods

    /// 获取产品（通过产品ID）
    func getProduct(by productId: String) -> Product? {
        return products.first { $0.id == productId }
    }

    /// 获取物资包定义（通过产品ID）
    func getSupplyPack(by productId: String) -> DBSupplyPackDefinition? {
        return supplyPacks.first { $0.productId == productId }
    }

    /// 格式化价格
    func formatPrice(_ product: Product) -> String {
        return product.displayPrice
    }

    /// 刷新所有数据
    func refreshAll() async {
        await loadProducts()
        await loadSupplyPacks()
        await loadMailbox()
    }
}

// MARK: - Insert Models

/// 插入购买记录的请求模型
struct InsertPurchaseRecord: Codable {
    let userId: UUID
    let productId: String
    let transactionId: String
    let purchaseDate: Date
    let environment: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case productId = "product_id"
        case transactionId = "transaction_id"
        case purchaseDate = "purchase_date"
        case environment
    }
}

/// 插入邮箱物品的请求模型
struct InsertMailboxItem: Codable {
    let userId: UUID
    let sourceType: String
    let sourceId: UUID?
    let title: String
    let items: [MailboxReward]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case sourceType = "source_type"
        case sourceId = "source_id"
        case title
        case items
    }
}

/// 更新邮箱物品领取状态的请求模型
struct UpdateMailboxItemClaim: Codable {
    let isClaimed: Bool
    let claimedAt: Date

    enum CodingKeys: String, CodingKey {
        case isClaimed = "is_claimed"
        case claimedAt = "claimed_at"
    }
}
