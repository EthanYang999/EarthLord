//
//  ActiveExplorationView.swift
//  EarthLord
//
//  Created on 2025/1/9.
//
//  正在进行的探索视图
//  显示当前行走距离、时间和停止按钮
//

import SwiftUI

/// 正在进行的探索视图
/// 显示在地图底部，包含实时探索数据和停止按钮
struct ActiveExplorationView: View {

    // MARK: - Properties

    /// 探索管理器
    @ObservedObject var explorationManager: ExplorationManager

    /// 停止探索回调
    var onStop: () -> Void

    // MARK: - State

    /// 脉冲动画状态
    @State private var isPulsing = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 顶部状态指示器
            HStack(spacing: 8) {
                // 脉冲圆点
                Circle()
                    .fill(ApocalypseTheme.success)
                    .frame(width: 10, height: 10)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0.6 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                        value: isPulsing
                    )

                Text("探索进行中")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.success)

                Spacer()

                // 时间显示
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(ExplorationManager.formatDuration(explorationManager.elapsedTime))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // 主要数据区域
            HStack(spacing: 20) {
                // 行走距离（大字）
                VStack(alignment: .leading, spacing: 4) {
                    Text("行走距离")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.0f", explorationManager.currentDistance))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .monospacedDigit()
                            .contentTransition(.numericText())

                        Text("m")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Spacer()

                // 奖励等级（根据当前距离）
                VStack(alignment: .trailing, spacing: 4) {
                    Text("奖励等级")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    HStack(spacing: 4) {
                        Text(explorationManager.currentRewardTier.icon)
                            .font(.title2)

                        Text(explorationManager.currentRewardTier.displayName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(tierColor)
                    }

                    // 预计物品数量
                    Text("\(explorationManager.currentRewardTier.itemCount) 件物品")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // 进度提示 - 距离下一等级
            if nextTierDistance > 0 {
                progressHint
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            // 停止按钮
            Button(action: onStop) {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.body)

                    Text("停止探索")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.red,
                            Color.red.opacity(0.8)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: -5)
        .onAppear {
            isPulsing = true
        }
    }

    // MARK: - Computed Properties

    /// 奖励等级颜色
    private var tierColor: Color {
        switch explorationManager.currentRewardTier {
        case .none: return ApocalypseTheme.textMuted
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.8)
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0)
        case .diamond: return Color(red: 0.5, green: 0.8, blue: 1.0)
        }
    }

    /// 下一等级所需距离
    private var nextTierDistance: Double {
        let current = explorationManager.currentDistance
        switch explorationManager.currentRewardTier {
        case .none: return RewardGenerator.bronzeThreshold - current
        case .bronze: return RewardGenerator.silverThreshold - current
        case .silver: return RewardGenerator.goldThreshold - current
        case .gold: return RewardGenerator.diamondThreshold - current
        case .diamond: return 0 // 已达到最高等级
        }
    }

    /// 下一等级名称
    private var nextTierName: String {
        switch explorationManager.currentRewardTier {
        case .none: return "铜级"
        case .bronze: return "银级"
        case .silver: return "金级"
        case .gold: return "钻石级"
        case .diamond: return ""
        }
    }

    /// 当前等级进度
    private var tierProgress: Double {
        let current = explorationManager.currentDistance
        switch explorationManager.currentRewardTier {
        case .none:
            return current / RewardGenerator.bronzeThreshold
        case .bronze:
            return (current - RewardGenerator.bronzeThreshold) / (RewardGenerator.silverThreshold - RewardGenerator.bronzeThreshold)
        case .silver:
            return (current - RewardGenerator.silverThreshold) / (RewardGenerator.goldThreshold - RewardGenerator.silverThreshold)
        case .gold:
            return (current - RewardGenerator.goldThreshold) / (RewardGenerator.diamondThreshold - RewardGenerator.goldThreshold)
        case .diamond:
            return 1.0
        }
    }

    // MARK: - Progress Hint

    /// 进度提示视图
    private var progressHint: some View {
        VStack(spacing: 6) {
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ApocalypseTheme.background)
                        .frame(height: 8)

                    // 进度
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    tierColor,
                                    tierColor.opacity(0.7)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(1, tierProgress), height: 8)
                        .animation(.easeOut(duration: 0.3), value: tierProgress)
                }
            }
            .frame(height: 8)

            // 提示文字
            if nextTierDistance > 0 {
                Text("再走 \(String(format: "%.0f", nextTierDistance)) 米升级到 \(nextTierName)")
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        VStack {
            Spacer()
            ActiveExplorationView(
                explorationManager: ExplorationManager.shared,
                onStop: {
                    print("停止探索")
                }
            )
        }
    }
}
