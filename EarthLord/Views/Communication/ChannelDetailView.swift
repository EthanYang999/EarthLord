//
//  ChannelDetailView.swift
//  EarthLord
//
//  频道详情页面
//  展示频道信息，提供订阅/取消订阅和删除功能
//

import SwiftUI
import Supabase

struct ChannelDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var manager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    let channel: CommunicationChannel

    // MARK: - State

    @State private var isProcessing = false
    @State private var showDeleteConfirm = false
    @State private var navigateToChat = false

    // MARK: - Computed Properties

    private var isCreator: Bool {
        authManager.currentUser?.id == channel.creatorId
    }

    private var isSubscribed: Bool {
        manager.isSubscribed(channelId: channel.id)
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 频道头像和基本信息
                    channelHeader

                    // 订阅状态标签
                    statusBadge

                    // 频道信息卡片
                    channelInfoCard

                    // 操作按钮
                    actionButtons

                    Spacer(minLength: 40)
                }
                .padding(16)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("频道详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .alert("删除频道", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteChannel()
            }
        } message: {
            Text("确定要删除「\(channel.name)」频道吗？此操作不可撤销，所有订阅者将失去该频道。")
        }
    }

    // MARK: - Channel Header

    private var channelHeader: some View {
        VStack(spacing: 16) {
            // 频道图标
            ZStack {
                Circle()
                    .fill(channelColor.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: channel.channelType.iconName)
                    .font(.system(size: 36))
                    .foregroundColor(channelColor)
            }

            // 频道名称
            Text(channel.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .multilineTextAlignment(.center)

            // 频道码
            HStack(spacing: 8) {
                Text(channel.channelCode)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Button(action: copyChannelCode) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(20)
        }
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: 12) {
            if isCreator {
                Label("创建者", systemImage: "crown.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(16)
            }

            if isSubscribed {
                Label("已订阅", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.success)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ApocalypseTheme.success.opacity(0.2))
                    .cornerRadius(16)
            }
        }
    }

    // MARK: - Channel Info Card

    private var channelInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 频道描述
            if let description = channel.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("频道介绍")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(nil)
                }
            }

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 频道信息列表
            VStack(spacing: 12) {
                infoRow(icon: "antenna.radiowaves.left.and.right", label: "频道类型", value: channel.channelType.displayName)
                infoRow(icon: "person.2.fill", label: "成员数量", value: "\(channel.memberCount) 人")
                infoRow(icon: "calendar", label: "创建时间", value: formatDate(channel.createdAt))
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 进入频道按钮（已订阅用户）
            if isSubscribed {
                NavigationLink(destination: ChannelChatView(channel: channel).environmentObject(authManager), isActive: $navigateToChat) {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                        Text("进入频道")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }

            // 订阅/取消订阅按钮（非创建者）
            if !isCreator {
                Button(action: toggleSubscription) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: isSubscribed ? "star.slash.fill" : "star.fill")
                        }
                        Text(isSubscribed ? "取消订阅" : "订阅频道")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isSubscribed ? ApocalypseTheme.warning : ApocalypseTheme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isProcessing)
            }

            // 删除按钮（创建者）
            if isCreator {
                Button(action: { showDeleteConfirm = true }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("删除频道")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.danger)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Helper Views

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    // MARK: - Helper Properties

    private var channelColor: Color {
        switch channel.channelType {
        case .official: return .yellow
        case .public: return .green
        case .walkie: return .blue
        case .camp: return .orange
        case .satellite: return .purple
        }
    }

    // MARK: - Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func copyChannelCode() {
        UIPasteboard.general.string = channel.channelCode
    }

    // MARK: - Actions

    private func toggleSubscription() {
        guard let userId = authManager.currentUser?.id else { return }

        isProcessing = true

        Task {
            if isSubscribed {
                _ = await manager.unsubscribeFromChannel(userId: userId, channelId: channel.id)
            } else {
                _ = await manager.subscribeToChannel(userId: userId, channelId: channel.id)
            }
            isProcessing = false
        }
    }

    private func deleteChannel() {
        guard let userId = authManager.currentUser?.id else { return }

        isProcessing = true

        Task {
            let success = await manager.deleteChannel(channelId: channel.id, userId: userId)
            isProcessing = false
            if success {
                dismiss()
            }
        }
    }
}

#Preview {
    let mockChannel = CommunicationChannel(
        id: UUID(),
        creatorId: UUID(),
        channelType: .public,
        channelCode: "PB-123456",
        name: "测试频道",
        description: "这是一个用于测试的公共频道，欢迎大家加入讨论。",
        isActive: true,
        memberCount: 42,
        location: nil,
        createdAt: Date(),
        updatedAt: Date()
    )

    ChannelDetailView(channel: mockChannel)
        .environmentObject(AuthManager())
}
