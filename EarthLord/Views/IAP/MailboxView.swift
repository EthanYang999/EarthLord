//
//  MailboxView.swift
//  EarthLord
//
//  邮箱页面
//

import SwiftUI

struct MailboxView: View {
    @ObservedObject private var iapManager = IAPManager.shared
    @State private var showClaimAllAlert = false
    @State private var claimAllResult: String?
    @State private var hasLoaded = false

    /// 未领取的邮件
    private var unclaimedItems: [DBMailboxItem] {
        iapManager.mailboxItems.filter { !$0.isClaimed }
    }

    /// 已领取的邮件
    private var claimedItems: [DBMailboxItem] {
        iapManager.mailboxItems.filter { $0.isClaimed }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 顶部操作栏
                    if !unclaimedItems.isEmpty {
                        claimAllButton
                    }

                    // 邮件列表
                    if iapManager.mailboxItems.isEmpty {
                        emptyMailboxView
                    } else {
                        mailboxList
                    }
                }
                .padding()
            }

            // 加载中
            if iapManager.isLoading && iapManager.mailboxItems.isEmpty {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .scaleEffect(1.5)
            }
        }
        .background(ApocalypseTheme.background)
        .onAppear {
            if !hasLoaded {
                hasLoaded = true
                Task {
                    await iapManager.loadMailbox()
                }
            }
        }
        .refreshable {
            await iapManager.loadMailbox()
        }
        .alert("一键领取", isPresented: $showClaimAllAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(claimAllResult ?? "")
        }
    }

    // MARK: - 一键领取按钮

    private var claimAllButton: some View {
        Button {
            Task {
                await claimAll()
            }
        } label: {
            HStack {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.subheadline)

                Text("一键领取全部 (\(unclaimedItems.count))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
    }

    // MARK: - 邮件列表

    private var mailboxList: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 未领取邮件
            if !unclaimedItems.isEmpty {
                sectionHeader(title: "待领取", count: unclaimedItems.count, color: ApocalypseTheme.primary)

                ForEach(unclaimedItems) { item in
                    MailboxItemRow(item: item) {
                        Task {
                            await claimItem(item)
                        }
                    }
                }
            }

            // 已领取邮件
            if !claimedItems.isEmpty {
                sectionHeader(title: "已领取", count: claimedItems.count, color: ApocalypseTheme.textMuted)

                ForEach(claimedItems) { item in
                    MailboxItemRow(item: item) {
                        // 已领取的不能再次领取
                    }
                }
            }
        }
    }

    private func sectionHeader(title: String, count: Int, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("(\(count))")
                .font(.subheadline)
                .foregroundColor(color)

            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - 空邮箱视图

    private var emptyMailboxView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 70))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("邮箱空空如也")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("购买物资包后，物品将发送到这里")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Actions

    private func claimItem(_ item: DBMailboxItem) async {
        let result = await iapManager.claimMailboxItem(item)
        switch result {
        case .success:
            print("[MailboxView] 领取成功: \(item.title)")
        case .failure(let error):
            print("[MailboxView] 领取失败: \(error.localizedDescription ?? "未知错误")")
        }
    }

    private func claimAll() async {
        let result = await iapManager.claimAllMailboxItems()
        switch result {
        case .success(let count):
            claimAllResult = "成功领取 \(count) 个物品到背包！"
        case .failure(let error):
            claimAllResult = error.localizedDescription ?? "领取失败"
        }
        showClaimAllAlert = true
    }
}

#Preview {
    MailboxView()
}
