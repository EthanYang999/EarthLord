//
//  StoreView.swift
//  EarthLord
//
//  物资商城页面
//

import SwiftUI
import StoreKit

struct StoreView: View {
    @ObservedObject private var iapManager = IAPManager.shared
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var showPurchaseSuccessAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 顶部横幅
                headerBanner

                // 物资包列表
                if iapManager.isLoading && iapManager.supplyPacks.isEmpty {
                    loadingView
                } else if iapManager.supplyPacks.isEmpty {
                    emptyView
                } else {
                    packsList
                }

                // 恢复购买按钮
                restorePurchasesButton

                // 底部说明
                footerNote
            }
            .padding()
        }
        .background(ApocalypseTheme.background)
        .navigationTitle("物资商城")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadStoreData()
        }
        .alert("恢复购买", isPresented: $showRestoreAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(restoreMessage)
        }
        .alert("购买成功", isPresented: $showPurchaseSuccessAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("物资已发放到您的邮箱，请前往资源页面的邮箱中领取！")
        }
        .onChange(of: iapManager.purchaseState) { _, newState in
            if case .success = newState {
                showPurchaseSuccessAlert = true
                iapManager.purchaseState = .idle
            }
        }
    }

    // MARK: - 顶部横幅

    private var headerBanner: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120)

                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("末日物资站")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("获取珍贵物资，在末日中生存")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - 物资包列表

    private var packsList: some View {
        VStack(spacing: 16) {
            ForEach(iapManager.supplyPacks) { pack in
                SupplyPackCard(
                    pack: pack,
                    product: iapManager.getProduct(by: pack.productId)
                ) {
                    Task {
                        await purchasePack(pack)
                    }
                }
            }
        }
    }

    // MARK: - 加载视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.5)

            Text("加载商品中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(height: 200)
    }

    // MARK: - 空视图

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart.badge.questionmark")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("暂无可用商品")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Button("重新加载") {
                Task {
                    await loadStoreData()
                }
            }
            .font(.subheadline)
            .foregroundColor(ApocalypseTheme.primary)
        }
        .frame(height: 200)
    }

    // MARK: - 恢复购买按钮

    private var restorePurchasesButton: some View {
        Button {
            Task {
                await restorePurchases()
            }
        } label: {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("恢复购买")
            }
            .font(.subheadline)
            .foregroundColor(ApocalypseTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)
        }
        .disabled(iapManager.isLoading)
    }

    // MARK: - 底部说明

    private var footerNote: some View {
        VStack(spacing: 8) {
            Text("购买后物资将发送至邮箱")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("消耗型商品，一次性使用")
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textMuted.opacity(0.7))
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func loadStoreData() async {
        await iapManager.loadSupplyPacks()
        await iapManager.loadProducts()
    }

    private func purchasePack(_ pack: DBSupplyPackDefinition) async {
        guard let product = iapManager.getProduct(by: pack.productId) else {
            print("[StoreView] 产品未找到: \(pack.productId)")
            return
        }

        let result = await iapManager.purchase(product)
        switch result {
        case .success:
            print("[StoreView] 购买成功")
        case .failure(let error):
            print("[StoreView] 购买失败: \(error.localizedDescription ?? "未知错误")")
        }
    }

    private func restorePurchases() async {
        let result = await iapManager.restorePurchases()
        switch result {
        case .success(let count):
            restoreMessage = count > 0 ? "已同步 \(count) 笔交易记录" : "没有找到需要恢复的购买"
        case .failure(let error):
            restoreMessage = error.localizedDescription ?? "恢复失败"
        }
        showRestoreAlert = true
    }
}

#Preview {
    NavigationStack {
        StoreView()
    }
}
