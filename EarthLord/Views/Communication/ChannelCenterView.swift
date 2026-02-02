//
//  ChannelCenterView.swift
//  EarthLord
//
//  频道中心页面
//  展示用户订阅的频道和可发现的公共频道
//

import SwiftUI
import Supabase

struct ChannelCenterView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var manager = CommunicationManager.shared

    // MARK: - State

    @State private var selectedTab: ChannelTab = .subscribed
    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var selectedChannel: CommunicationChannel?

    enum ChannelTab: String, CaseIterable {
        case subscribed = "我的频道"
        case discover = "发现频道"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 顶部操作栏
            headerBar

            // Tab 切换
            tabBar

            // 搜索框（仅发现页面）
            if selectedTab == .discover {
                searchBar
            }

            // 频道列表
            channelList

            Spacer(minLength: 0)
        }
        .background(ApocalypseTheme.background)
        .onAppear {
            loadData()
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateChannelSheet()
                .environmentObject(authManager)
        }
        .sheet(item: $selectedChannel) { channel in
            // ✅ Day 36: 区分官方频道和普通频道
            if manager.isOfficialChannel(channel.id) {
                OfficialChannelDetailView(channel: channel)
            } else {
                ChannelDetailView(channel: channel)
                    .environmentObject(authManager)
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Text("频道中心")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            Button(action: { showCreateSheet = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ChannelTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                            .foregroundColor(selectedTab == tab ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)

                        Rectangle()
                            .fill(selectedTab == tab ? ApocalypseTheme.primary : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textSecondary)

            TextField("搜索频道名称或频道码", text: $searchText)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .onSubmit {
                    Task {
                        await manager.searchChannels(query: searchText)
                    }
                }

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    Task {
                        await manager.loadPublicChannels()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Channel List

    private var channelList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if manager.isLoading {
                    ProgressView()
                        .tint(ApocalypseTheme.primary)
                        .padding(.top, 40)
                } else if selectedTab == .subscribed {
                    subscribedChannelList
                } else {
                    discoverChannelList
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Subscribed Channel List

    private var subscribedChannelList: some View {
        Group {
            if manager.subscribedChannels.isEmpty {
                emptyStateView(
                    icon: "star.slash",
                    title: "暂无订阅频道",
                    subtitle: "去「发现频道」订阅感兴趣的频道"
                )
            } else {
                ForEach(manager.subscribedChannels) { subscribedChannel in
                    ChannelRowView(
                        channel: subscribedChannel.channel,
                        isSubscribed: true,
                        isMuted: subscribedChannel.isMuted
                    )
                    .onTapGesture {
                        selectedChannel = subscribedChannel.channel
                    }
                }
            }
        }
    }

    // MARK: - Discover Channel List

    private var discoverChannelList: some View {
        Group {
            if manager.channels.isEmpty {
                emptyStateView(
                    icon: "antenna.radiowaves.left.and.right.slash",
                    title: "暂无公共频道",
                    subtitle: "成为第一个创建频道的人吧"
                )
            } else {
                ForEach(manager.channels) { channel in
                    ChannelRowView(
                        channel: channel,
                        isSubscribed: manager.isSubscribed(channelId: channel.id),
                        isMuted: false
                    )
                    .onTapGesture {
                        selectedChannel = channel
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(title)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Helper Methods

    private func loadData() {
        guard let userId = authManager.currentUser?.id else { return }
        Task {
            await manager.loadSubscribedChannels(userId: userId)
            await manager.loadPublicChannels()
        }
    }
}

// MARK: - Channel Row View

struct ChannelRowView: View {
    let channel: CommunicationChannel
    let isSubscribed: Bool
    let isMuted: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 频道图标
            ZStack {
                Circle()
                    .fill(channelColor.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: channel.channelType.iconName)
                    .font(.title3)
                    .foregroundColor(channelColor)
            }

            // 频道信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(channel.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)

                    if isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                HStack(spacing: 8) {
                    Text(channel.channelCode)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("·")
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("\(channel.memberCount) 成员")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Spacer()

            // 订阅状态
            if isSubscribed {
                Text("已订阅")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.success.opacity(0.2))
                    .cornerRadius(4)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private var channelColor: Color {
        switch channel.channelType {
        case .official: return .yellow
        case .public: return .green
        case .walkie: return .blue
        case .camp: return .orange
        case .satellite: return .purple
        }
    }
}

#Preview {
    ChannelCenterView()
        .environmentObject(AuthManager())
}
