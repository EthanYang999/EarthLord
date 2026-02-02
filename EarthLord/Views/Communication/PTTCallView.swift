//
//  PTTCallView.swift
//  EarthLord
//
//  PTT (Push To Talk) 通话页面
//  Day 36 实现 - 长按发送，对讲机体验
//

import SwiftUI
import Auth
import CoreLocation

struct PTTCallView: View {
    @StateObject private var communicationManager = CommunicationManager.shared
    @EnvironmentObject var authManager: AuthManager

    @State private var selectedChannelIndex = 0
    @State private var messageText = ""
    @State private var isPressingPTT = false
    @State private var showSuccessToast = false
    @FocusState private var isInputFocused: Bool  // ✅ 键盘管理

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 标题栏
                headerBar

                Divider()
                    .background(ApocalypseTheme.textSecondary.opacity(0.3))

                // 频率卡片
                frequencyCard

                // 频道切换标签
                channelTabs

                Divider()
                    .background(ApocalypseTheme.textSecondary.opacity(0.3))

                Spacer()

                // 消息输入区
                messageInputArea

                // PTT 按钮
                pttButton
                    .padding(.bottom, 40)
            }

            // 成功提示 Toast
            if showSuccessToast {
                toastView
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Text("PTT 通话")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 当前设备指示器
            if let device = communicationManager.currentDevice {
                HStack(spacing: 4) {
                    Image(systemName: device.deviceType.iconName)
                        .font(.system(size: 12))
                    Text(device.deviceType.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ApocalypseTheme.primary.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - Frequency Card

    private var frequencyCard: some View {
        VStack(spacing: 12) {
            if let channel = selectedChannel {
                // 频道图标
                Image(systemName: channel.channelType.iconName)
                    .font(.system(size: 40))
                    .foregroundColor(ApocalypseTheme.primary)

                // 频道名称
                Text(channel.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 频道码
                Text(channel.channelCode)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.textSecondary.opacity(0.2))
                    .cornerRadius(8)
            } else {
                Text("未选择频道")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - Channel Tabs

    private var channelTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(availableChannels.enumerated()), id: \.offset) { index, channel in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedChannelIndex = index
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: channel.channelType.iconName)
                                .font(.system(size: 16))
                            Text(channel.name)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedChannelIndex == index ? .white : ApocalypseTheme.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(selectedChannelIndex == index ? ApocalypseTheme.primary : ApocalypseTheme.primary.opacity(0.2))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - Message Input Area

    private var messageInputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("消息内容")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            ZStack(alignment: .topLeading) {
                // ✅ 修复 TextEditor 显示问题
                TextEditor(text: $messageText)
                    .frame(height: 80)
                    .padding(8)
                    .scrollContentBackground(.hidden)  // ✅ 隐藏默认白色背景
                    .background(Color.clear)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .focused($isInputFocused)  // ✅ 绑定焦点状态
                    .tint(ApocalypseTheme.primary)  // 光标颜色

                // 占位符文本
                if messageText.isEmpty {
                    Text("输入消息内容...")
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .background(ApocalypseTheme.cardBackground)  // ✅ 背景放在外层
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ApocalypseTheme.textSecondary.opacity(0.3), lineWidth: 1)
            )

            Text("长按下方按钮发送消息")
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - PTT Button

    private var pttButton: some View {
        ZStack {
            // 按下时的扩散效果
            if isPressingPTT {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.3))
                    .frame(width: 180, height: 180)
                    .scaleEffect(isPressingPTT ? 1.2 : 1.0)
                    .animation(.easeOut(duration: 0.3).repeatForever(autoreverses: false), value: isPressingPTT)
            }

            // 主按钮
            Circle()
                .fill(isPressingPTT ? ApocalypseTheme.primary : ApocalypseTheme.primary.opacity(0.8))
                .frame(width: 140, height: 140)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: isPressingPTT ? "mic.fill" : "mic")
                            .font(.system(size: 40))
                        Text(isPressingPTT ? "松开发送" : "按住通话")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                )
                .scaleEffect(isPressingPTT ? 1.1 : 1.0)
                .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: isPressingPTT ? 20 : 10)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.1)
                .onChanged { _ in
                    if !isPressingPTT {
                        isInputFocused = false  // ✅ 关闭键盘
                        isPressingPTT = true
                        triggerHapticFeedback()
                    }
                }
                .onEnded { _ in
                    isPressingPTT = false
                    sendPTTMessage()
                }
        )
    }

    // MARK: - Toast View

    private var toastView: some View {
        VStack {
            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)

                Text("消息已发送")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 10)
            .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showSuccessToast = false
                }
            }
        }
    }

    // MARK: - Computed Properties

    /// 可用频道（排除官方频道）
    private var availableChannels: [CommunicationChannel] {
        communicationManager.subscribedChannels
            .map { $0.channel }
            .filter { !communicationManager.isOfficialChannel($0.id) }
    }

    /// 当前选中的频道
    private var selectedChannel: CommunicationChannel? {
        guard !availableChannels.isEmpty, selectedChannelIndex < availableChannels.count else {
            return nil
        }
        return availableChannels[selectedChannelIndex]
    }

    // MARK: - Methods

    /// 触发震动反馈
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// 发送 PTT 消息
    private func sendPTTMessage() {
        guard let channel = selectedChannel,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        Task {
            // 获取当前位置（可选）
            let location = LocationManager.shared.userLocation

            let success = await communicationManager.sendChannelMessage(
                channelId: channel.id,
                content: messageText,
                latitude: location?.latitude,
                longitude: location?.longitude
            )

            if success {
                // 清空输入框
                await MainActor.run {
                    messageText = ""

                    // 显示成功提示
                    withAnimation {
                        showSuccessToast = true
                    }
                }

                // 再次震动反馈
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
}

#Preview {
    PTTCallView()
        .environmentObject(AuthManager())
}
