//
//  OfficialChannelDetailView.swift
//  EarthLord
//
//  官方频道详情页面
//  Day 36 实现 - 带分类过滤的官方公告
//

import SwiftUI

struct OfficialChannelDetailView: View {
    let channel: CommunicationChannel

    @StateObject private var communicationManager = CommunicationManager.shared
    @State private var selectedCategory: MessageCategory? = nil
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 导航栏
                navigationBar

                Divider()
                    .background(ApocalypseTheme.textSecondary.opacity(0.3))

                // 分类过滤器
                categoryFilters

                Divider()
                    .background(ApocalypseTheme.textSecondary.opacity(0.3))

                // 消息列表
                if isLoading {
                    loadingView
                } else if filteredMessages.isEmpty {
                    emptyView
                } else {
                    messageList
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadMessages()
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("官方公告")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 官方标识
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12))
                Text("官方")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.yellow)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.yellow.opacity(0.2))
            .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - Category Filters

    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "全部" 按钮
                CategoryChip(
                    title: "全部",
                    icon: "tray.fill",
                    color: .gray,
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )

                // 各分类按钮
                ForEach(MessageCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.displayName,
                        icon: category.iconName,
                        color: category.color,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredMessages) { message in
                    OfficialMessageBubble(message: message)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: selectedCategory?.iconName ?? "tray")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(selectedCategory == nil ? "暂无公告" : "该分类暂无消息")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("请稍后查看")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(ApocalypseTheme.primary)
            Text("加载中...")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - Computed Properties

    private var messages: [ChannelMessage] {
        communicationManager.channelMessages[channel.id] ?? []
    }

    private var filteredMessages: [ChannelMessage] {
        if let category = selectedCategory {
            return messages.filter { $0.category == category }
        }
        return messages
    }

    // MARK: - Methods

    private func loadMessages() {
        isLoading = true
        Task {
            await communicationManager.loadChannelMessages(channelId: channel.id)
            isLoading = false
        }
    }
}

// MARK: - Category Chip Component

struct CategoryChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : color.opacity(0.2))
            .cornerRadius(16)
        }
    }
}

// MARK: - Official Message Bubble Component

struct OfficialMessageBubble: View {
    let message: ChannelMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 分类标签 + 时间
            HStack {
                if let category = message.category {
                    Label(category.displayName, systemImage: category.iconName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(category.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(category.color.opacity(0.2))
                        .cornerRadius(8)
                }

                Spacer()

                Text(message.timeAgo)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 消息内容
            Text(message.content)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(message.category?.color.opacity(0.3) ?? ApocalypseTheme.textSecondary.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

#Preview {
    OfficialChannelDetailView(
        channel: CommunicationChannel(
            id: CommunicationManager.officialChannelId,
            creatorId: UUID(),
            channelType: .official,
            channelCode: "OFF-MAIN",
            name: "官方频道",
            description: "官方公告",
            isActive: true,
            memberCount: 0,
            location: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    )
}
