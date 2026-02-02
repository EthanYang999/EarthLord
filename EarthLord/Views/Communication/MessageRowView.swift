//
//  MessageRowView.swift
//  EarthLord
//
//  消息行组件（用于消息中心）
//  Day 36 实现
//

import SwiftUI

struct MessageRowView: View {
    let summary: CommunicationManager.ChannelSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 频道图标
            channelIcon

            // 消息内容
            VStack(alignment: .leading, spacing: 4) {
                // 频道名称 + 官方标签
                HStack(spacing: 6) {
                    Text(summary.channel.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)

                    if summary.channel.channelType == .official {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                            Text("官方")
                                .font(.caption2)
                        }
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(4)
                    }

                    Spacer()

                    // 时间显示
                    if let lastMessage = summary.lastMessage {
                        Text(lastMessage.timeAgo)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                // 最新消息预览
                if let lastMessage = summary.lastMessage {
                    HStack(spacing: 4) {
                        // 呼号（如果有）
                        if let callsign = lastMessage.senderCallsign {
                            Text("\(callsign):")
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.primary)
                                .lineLimit(1)
                        }

                        // 消息内容
                        Text(lastMessage.content)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .lineLimit(2)
                    }
                } else {
                    Text("暂无消息")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.6))
                }
            }

            // 未读数量徽章（TODO: 未来实现）
            if summary.unreadCount > 0 {
                Text("\(summary.unreadCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .cornerRadius(10)
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Channel Icon

    private var channelIcon: some View {
        ZStack {
            Circle()
                .fill(channelColor.opacity(0.2))
                .frame(width: 48, height: 48)

            Image(systemName: summary.channel.channelType.iconName)
                .font(.system(size: 20))
                .foregroundColor(channelColor)
        }
    }

    private var channelColor: Color {
        switch summary.channel.channelType {
        case .official:
            return .yellow
        case .public:
            return .green
        case .walkie:
            return .blue
        case .camp:
            return .orange
        case .satellite:
            return .purple
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        // 官方频道示例
        MessageRowView(
            summary: CommunicationManager.ChannelSummary(
                channel: CommunicationChannel(
                    id: UUID(),
                    creatorId: UUID(),
                    channelType: .official,
                    channelCode: "OFF-MAIN",
                    name: "官方频道",
                    description: "官方公告",
                    isActive: true,
                    memberCount: 100,
                    location: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                lastMessage: ChannelMessage(
                    messageId: UUID(),
                    channelId: UUID(),
                    senderId: UUID(),
                    senderCallsign: "系统",
                    content: "欢迎来到地球领主！",
                    senderLocation: nil,
                    metadata: nil,
                    createdAt: Date().addingTimeInterval(-3600),
                    senderDeviceType: nil
                ),
                unreadCount: 3
            )
        )

        // 普通频道示例
        MessageRowView(
            summary: CommunicationManager.ChannelSummary(
                channel: CommunicationChannel(
                    id: UUID(),
                    creatorId: UUID(),
                    channelType: .public,
                    channelCode: "PUB-001",
                    name: "生存者联盟",
                    description: "幸存者交流",
                    isActive: true,
                    memberCount: 50,
                    location: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                lastMessage: ChannelMessage(
                    messageId: UUID(),
                    channelId: UUID(),
                    senderId: UUID(),
                    senderCallsign: "Alpha-01",
                    content: "有人在附近吗？需要支援！",
                    senderLocation: nil,
                    metadata: nil,
                    createdAt: Date().addingTimeInterval(-300),
                    senderDeviceType: .walkieTalkie
                ),
                unreadCount: 0
            )
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
