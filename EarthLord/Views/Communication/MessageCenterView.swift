//
//  MessageCenterView.swift
//  EarthLord
//
//  消息中心页面 - 汇总所有频道的最新消息
//  Day 36 实现
//

import SwiftUI

struct MessageCenterView: View {
    @StateObject private var communicationManager = CommunicationManager.shared
    @EnvironmentObject var authManager: AuthManager

    @State private var isLoading = false
    @State private var selectedChannel: CommunicationChannel?

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 标题栏
                    headerBar

                    Divider()
                        .background(ApocalypseTheme.textSecondary.opacity(0.3))

                    // 内容区域
                    if isLoading {
                        loadingView
                    } else if channelSummaries.isEmpty {
                        emptyView
                    } else {
                        messageList
                    }
                }
            }
            .navigationDestination(item: $selectedChannel) { channel in
                // 根据频道类型导航到不同页面
                if communicationManager.isOfficialChannel(channel.id) {
                    OfficialChannelDetailView(channel: channel)
                } else {
                    ChannelChatView(channel: channel)
                }
            }
            .onAppear {
                loadData()
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Text("消息中心")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 刷新按钮
            Button(action: { loadData() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.primary)
                    .rotationEffect(.degrees(isLoading ? 360 : 0))
                    .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
            }
            .disabled(isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(channelSummaries) { summary in
                    MessageRowView(summary: summary)
                        .onTapGesture {
                            selectedChannel = summary.channel
                        }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bell.slash")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("暂无消息")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("订阅频道后，消息会在这里显示")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
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

    private var channelSummaries: [CommunicationManager.ChannelSummary] {
        communicationManager.getChannelSummaries()
    }

    // MARK: - Methods

    private func loadData() {
        guard let userId = authManager.currentUser?.id else { return }

        isLoading = true
        Task {
            // 先加载订阅的频道
            await communicationManager.loadSubscribedChannels(userId: userId)

            // 再加载所有频道的最新消息
            await communicationManager.loadAllChannelLatestMessages()

            isLoading = false
        }
    }
}

#Preview {
    MessageCenterView()
        .environmentObject(AuthManager())
}
