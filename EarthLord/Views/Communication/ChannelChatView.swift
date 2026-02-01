//
//  ChannelChatView.swift
//  EarthLord
//
//  聊天界面页面
//  展示频道消息列表，支持发送消息和实时接收
//

import SwiftUI
import Supabase
import CoreLocation

struct ChannelChatView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var manager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    let channel: CommunicationChannel

    // MARK: - State

    @State private var messageText = ""
    @State private var isLoading = true
    @FocusState private var isInputFocused: Bool

    // MARK: - Computed Properties

    private var messages: [ChannelMessage] {
        manager.getMessages(for: channel.id)
    }

    private var canSend: Bool {
        manager.canSendMessage()
    }

    private var currentUserId: UUID? {
        authManager.currentUser?.id
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 导航栏
            navigationBar

            // 消息列表
            messageList

            // 输入栏或收音机提示
            if canSend {
                inputBar
            } else {
                radioModeHint
            }
        }
        .background(ApocalypseTheme.background)
        .navigationBarHidden(true)
        .onAppear {
            setupChat()
        }
        .onDisappear {
            cleanupChat()
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack(spacing: 12) {
            // 返回按钮
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // 频道图标
            ZStack {
                Circle()
                    .fill(channelColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: channel.channelType.iconName)
                    .font(.body)
                    .foregroundColor(channelColor)
            }

            // 频道信息
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .tint(ApocalypseTheme.primary)
                            .padding(.top, 40)
                    } else if messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                isOwnMessage: message.senderId == currentUserId
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) {
                // 自动滚动到最新消息
                if let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("暂无消息")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("成为第一个发言的人吧")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            // 输入框
            TextField("输入消息...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(20)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .focused($isInputFocused)
                .lineLimit(1...5)

            // 发送按钮
            Button(action: sendMessage) {
                ZStack {
                    Circle()
                        .fill(canSendNow ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3))
                        .frame(width: 40, height: 40)

                    if manager.isSendingMessage {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.body)
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(!canSendNow || manager.isSendingMessage)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.background)
    }

    // MARK: - Radio Mode Hint

    private var radioModeHint: some View {
        HStack(spacing: 12) {
            Image(systemName: "radio")
                .font(.title3)
                .foregroundColor(ApocalypseTheme.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text("收音机模式")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("只能接收信号，无法发送消息")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 切换设备提示
            Text("切换设备以发送")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.primary)
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
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

    private var canSendNow: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func setupChat() {
        Task {
            // 启动 Realtime 订阅
            await manager.startRealtimeSubscription()

            // 添加当前频道到监听列表
            manager.subscribeToChannelMessages(channelId: channel.id)

            // 加载历史消息
            await manager.loadChannelMessages(channelId: channel.id)

            isLoading = false
        }
    }

    private func cleanupChat() {
        // 从监听列表移除
        manager.unsubscribeFromChannelMessages(channelId: channel.id)

        // 如果没有其他频道在监听，停止 Realtime
        if manager.subscribedChannelIds.isEmpty {
            Task {
                await manager.stopRealtimeSubscription()
            }
        }
    }

    private func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        // ✅ 从 LocationManager 获取真实 GPS 位置
        let location = LocationManager.shared.userLocation
        let latitude = location?.latitude
        let longitude = location?.longitude

        // 🔍 调试日志：检查位置是否获取到
        if let lat = latitude, let lon = longitude {
            print("📤 [发送消息] 位置已获取: \(lat), \(lon)")
        } else {
            print("⚠️ [发送消息] 位置未获取: location=\(location?.latitude ?? 0), \(location?.longitude ?? 0)")
            print("⚠️ [发送消息] LocationManager.userLocation = \(String(describing: LocationManager.shared.userLocation))")
        }

        let textToSend = content
        messageText = ""
        isInputFocused = false

        Task {
            let success = await manager.sendChannelMessage(
                channelId: channel.id,
                content: textToSend,
                latitude: latitude,
                longitude: longitude
            )

            if !success {
                // 发送失败，恢复文本
                messageText = textToSend
            }
        }
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: ChannelMessage
    let isOwnMessage: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOwnMessage {
                Spacer(minLength: 60)
            }

            VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 4) {
                // 发送者信息（他人消息）
                if !isOwnMessage {
                    HStack(spacing: 6) {
                        Text(message.senderCallsign ?? "匿名")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        if let deviceType = message.deviceType {
                            Image(systemName: deviceType.iconName)
                                .font(.caption2)
                                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
                        }

                        // ✅ 新增：显示距离
                        if let distanceText = formattedDistance {
                            HStack(spacing: 2) {
                                Image(systemName: "location.fill")
                                    .font(.caption2)
                                Text(distanceText)
                                    .font(.caption2)
                            }
                            .foregroundColor(distanceColor)
                        }
                    }
                }

                // 消息内容
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isOwnMessage ? .white : ApocalypseTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isOwnMessage ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                    .cornerRadius(16)

                // 时间
                Text(message.timeAgo)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
            }

            if !isOwnMessage {
                Spacer(minLength: 60)
            }
        }
    }

    // MARK: - 距离计算

    /// 计算并格式化距离显示
    private var formattedDistance: String? {
        // 自己的消息不显示距离
        if isOwnMessage {
            return nil
        }

        // 获取发送者位置
        guard let senderLocation = message.senderLocation else {
            return "未知"
        }

        // 获取当前用户位置
        guard let myLocation = LocationManager.shared.userLocation else {
            return "未知"
        }

        // 计算距离（公里）
        let distance = calculateDistance(
            from: myLocation,
            to: CLLocationCoordinate2D(
                latitude: senderLocation.latitude,
                longitude: senderLocation.longitude
            )
        )

        // 格式化显示
        if distance < 1.0 {
            // 小于 1km，显示米
            return String(format: "%.0fm", distance * 1000)
        } else if distance < 10.0 {
            // 1-10km，显示一位小数
            return String(format: "%.1fkm", distance)
        } else {
            // 大于 10km，显示整数
            return String(format: "%.0fkm", distance)
        }
    }

    /// 根据距离返回颜色
    private var distanceColor: Color {
        guard let senderLocation = message.senderLocation,
              let myLocation = LocationManager.shared.userLocation else {
            return .gray
        }

        let distance = calculateDistance(
            from: myLocation,
            to: CLLocationCoordinate2D(
                latitude: senderLocation.latitude,
                longitude: senderLocation.longitude
            )
        )

        // 颜色编码：根据通讯设备范围
        if distance <= 3.0 {
            return .green  // 对讲机范围内（0-3km）
        } else if distance <= 30.0 {
            return .orange  // 营地电台范围（3-30km）
        } else if distance <= 100.0 {
            return .purple  // 卫星通讯范围（30-100km）
        } else {
            return .red  // 超出所有设备范围
        }
    }

    /// 计算两点之间的距离（公里）
    private func calculateDistance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let fromLocation = CLLocation(
            latitude: from.latitude,
            longitude: from.longitude
        )
        let toLocation = CLLocation(
            latitude: to.latitude,
            longitude: to.longitude
        )
        return fromLocation.distance(from: toLocation) / 1000.0
    }
}

#Preview {
    let mockChannel = CommunicationChannel(
        id: UUID(),
        creatorId: UUID(),
        channelType: .public,
        channelCode: "PB-123456",
        name: "测试频道",
        description: "这是一个测试频道",
        isActive: true,
        memberCount: 42,
        location: nil,
        createdAt: Date(),
        updatedAt: Date()
    )

    return ChannelChatView(channel: mockChannel)
        .environmentObject(AuthManager())
}
