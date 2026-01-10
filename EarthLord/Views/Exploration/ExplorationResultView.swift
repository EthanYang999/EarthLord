//
//  ExplorationResultView.swift
//  EarthLord
//
//  Created on 2025/1/8.
//
//  探索结果页面
//  展示本次探索的统计数据和获得的物品
//

import SwiftUI

struct ExplorationResultView: View {

    // MARK: - Properties

    /// 探索结果数据（成功时有值）
    let result: ExplorationResult?

    /// 错误信息（失败时有值）
    let errorMessage: String?

    /// 重试回调
    var onRetry: (() -> Void)?

    /// 环境变量 - 用于关闭页面
    @Environment(\.dismiss) private var dismiss

    // MARK: - Initializers

    /// 成功状态初始化
    init(result: ExplorationResult) {
        self.result = result
        self.errorMessage = nil
        self.onRetry = nil
    }

    /// 错误状态初始化
    init(errorMessage: String, onRetry: (() -> Void)? = nil) {
        self.result = nil
        self.errorMessage = errorMessage
        self.onRetry = onRetry
    }

    // MARK: - State

    /// 动画状态
    @State private var showContent = false
    @State private var showItems = false
    @State private var showError = false

    /// 动画数值 - 行走距离
    @State private var animatedWalkDistance: Double = 0
    @State private var animatedTotalWalkDistance: Double = 0

    /// 动画数值 - 时长和排名
    @State private var animatedDuration: Int = 0
    @State private var animatedWalkRank: Int = 0

    /// 奖励物品出现状态
    @State private var itemAppearStates: [String: Bool] = [:]

    /// 对勾弹跳状态
    @State private var checkmarkScales: [String: CGFloat] = [:]

    // MARK: - Computed Properties

    /// 是否为错误状态
    private var isError: Bool {
        errorMessage != nil
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            if isError {
                // 错误状态
                errorStateView
            } else if let result = result {
                // 成功状态
                successStateView(result: result)
            }
        }
        .onAppear {
            if isError {
                startErrorAnimations()
            } else {
                startAnimations()
            }
        }
    }

    // MARK: - Success State

    /// 成功状态视图
    private func successStateView(result: ExplorationResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // 成就标题
                achievementHeader
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -20)

                // 统计数据卡片
                statsCard
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)

                // 奖励物品卡片
                rewardsCard
                    .opacity(showItems ? 1 : 0)
                    .scaleEffect(showItems ? 1 : 0.9)

                // 确认按钮
                confirmButton
                    .opacity(showItems ? 1 : 0)

                Spacer(minLength: 40)
            }
            .padding()
        }
    }

    // MARK: - Error State

    /// 错误状态视图
    private var errorStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // 错误图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.danger.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.danger)
            }
            .opacity(showError ? 1 : 0)
            .scaleEffect(showError ? 1 : 0.5)

            // 错误标题
            Text("探索失败")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .opacity(showError ? 1 : 0)

            // 错误信息
            Text(errorMessage ?? "发生未知错误")
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .opacity(showError ? 1 : 0)

            Spacer()

            // 按钮区域
            VStack(spacing: 12) {
                // 重试按钮
                if let onRetry = onRetry {
                    Button {
                        onRetry()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.headline)

                            Text("重试")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(12)
                    }
                }

                // 关闭按钮
                Button {
                    dismiss()
                } label: {
                    Text("关闭")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
            .opacity(showError ? 1 : 0)
        }
    }

    /// 开始错误状态动画
    private func startErrorAnimations() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            showError = true
        }
    }

    // MARK: - Achievement Header

    /// 奖励等级颜色
    private var tierColor: Color {
        guard let result = result else { return ApocalypseTheme.primary }
        switch result.rewardTier {
        case .none: return ApocalypseTheme.textMuted
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.8)
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0)
        case .diamond: return Color(red: 0.5, green: 0.8, blue: 1.0)
        }
    }

    /// 成就标题区域
    private var achievementHeader: some View {
        VStack(spacing: 16) {
            // 装饰光环
            ZStack {
                // 外圈光晕
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                tierColor.opacity(0.3),
                                tierColor.opacity(0)
                            ]),
                            center: .center,
                            startRadius: 40,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                // 内圈背景
                Circle()
                    .fill(tierColor.opacity(0.2))
                    .frame(width: 100, height: 100)

                // 奖励等级图标
                if let tier = result?.rewardTier {
                    Text(tier.icon)
                        .font(.system(size: 50))
                } else {
                    Image(systemName: "map.fill")
                        .font(.system(size: 50))
                        .foregroundColor(tierColor)
                }
            }

            // 标题文字
            Text("探索完成！")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 奖励等级
            if let tier = result?.rewardTier, tier != .none {
                HStack(spacing: 8) {
                    Text("奖励等级")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(tier.displayName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(tierColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(tierColor.opacity(0.2))
                        .cornerRadius(8)
                }
            } else {
                // 副标题
                Text("行走距离不足，下次走远一点吧")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Stats Card

    /// 统计数据卡片
    private var statsCard: some View {
        VStack(spacing: 0) {
            // 行走距离
            statRow(
                icon: "figure.walk",
                iconColor: ApocalypseTheme.info,
                title: "行走距离",
                current: formatDistance(animatedWalkDistance),
                total: formatDistance(animatedTotalWalkDistance),
                rank: animatedWalkRank
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 探索时长
            HStack {
                // 图标
                Image(systemName: "clock.fill")
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.warning)
                    .frame(width: 40)

                // 标题
                Text("探索时长")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 时长（使用动画数值）
                Text("\(animatedDuration) 分钟")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .contentTransition(.numericText())
            }
            .padding()
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 统计行
    private func statRow(
        icon: String,
        iconColor: Color,
        title: String,
        current: String,
        total: String,
        rank: Int
    ) -> some View {
        HStack(alignment: .center) {
            // 图标
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 40)

            // 标题和数据
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                HStack(spacing: 12) {
                    // 本次
                    VStack(alignment: .leading, spacing: 2) {
                        Text("本次")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Text(current)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }

                    // 累计
                    VStack(alignment: .leading, spacing: 2) {
                        Text("累计")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Text(total)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                }
            }

            Spacer()

            // 排名
            VStack(spacing: 2) {
                Text("排名")
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("#\(rank)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.success)
            }
        }
        .padding()
    }

    // MARK: - Rewards Card

    /// 奖励物品卡片
    private var rewardsCard: some View {
        let items = result?.obtainedItems ?? []

        return VStack(spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "gift.fill")
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.warning)

                Text("获得物品")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 物品数量
                Text("\(items.count) 件")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(.horizontal)
            .padding(.top)

            // 物品列表 - 带依次出现动画
            VStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    rewardItemRow(item: item, index: index)
                        .opacity(itemAppearStates[item.id] == true ? 1 : 0)
                        .offset(x: itemAppearStates[item.id] == true ? 0 : -30)
                }
            }
            .padding(.horizontal)

            // 底部提示
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.success)

                Text("已添加到背包")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.success)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(ApocalypseTheme.success.opacity(0.1))
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 奖励物品行
    private func rewardItemRow(item: ObtainedItem, index: Int) -> some View {
        HStack(spacing: 12) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.warning.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: itemIcon(for: item.itemName))
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.warning)
            }

            // 物品名称
            Text(item.itemName)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 品质（如有）
            if let quality = item.quality {
                Text(quality.rawValue)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ApocalypseTheme.background)
                    .cornerRadius(4)
            }

            Spacer()

            // 数量
            Text("x\(item.quantity)")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.primary)

            // 对勾 - 带弹跳动画
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundColor(ApocalypseTheme.success)
                .scaleEffect(checkmarkScales[item.id] ?? 0)
        }
        .padding(12)
        .background(ApocalypseTheme.background)
        .cornerRadius(10)
        .onAppear {
            // 依次出现，每个间隔0.2秒
            let delay = 0.5 + Double(index) * 0.2
            withAnimation(.easeOut(duration: 0.3).delay(delay)) {
                itemAppearStates[item.id] = true
            }
            // 对勾弹跳效果，稍微延后
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(delay + 0.2)) {
                checkmarkScales[item.id] = 1.0
            }
        }
    }

    // MARK: - Confirm Button

    /// 确认按钮
    private var confirmButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.headline)

                Text("确认")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        ApocalypseTheme.primary,
                        ApocalypseTheme.primaryDark
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
    }

    // MARK: - Helper Methods

    /// 开始动画
    private func startAnimations() {
        // 内容淡入
        withAnimation(.easeOut(duration: 0.5)) {
            showContent = true
        }

        // 奖励卡片出现
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            showItems = true
        }

        // 数字跳动动画 - 使用定时器模拟数字增长
        startNumberAnimation()
    }

    /// 数字跳动动画
    private func startNumberAnimation() {
        guard let result = result else { return }

        let duration: Double = 1.0
        let steps = 20
        let interval = duration / Double(steps)

        for i in 0...steps {
            let progress = Double(i) / Double(steps)
            let delay = 0.3 + interval * Double(i)

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // 使用缓动函数让数字变化更自然
                let easedProgress = self.easeOutQuad(progress)

                withAnimation(.linear(duration: interval)) {
                    self.animatedWalkDistance = result.walkDistance * easedProgress
                    self.animatedTotalWalkDistance = result.totalWalkDistance * easedProgress
                    self.animatedDuration = Int(Double(result.durationMinutes) * easedProgress)
                    self.animatedWalkRank = max(1, Int(Double(result.walkDistanceRank) * easedProgress))
                }
            }
        }
    }

    /// 缓动函数 - easeOutQuad
    private func easeOutQuad(_ t: Double) -> Double {
        return 1 - (1 - t) * (1 - t)
    }

    /// 格式化距离
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    /// 根据物品名称获取图标
    private func itemIcon(for name: String) -> String {
        switch name {
        case "木材":
            return "cube.box.fill"
        case "矿泉水":
            return "drop.fill"
        case "罐头食品", "罐头":
            return "fork.knife"
        case "绷带":
            return "bandage.fill"
        case "急救药品":
            return "cross.case.fill"
        case "废金属":
            return "gearshape.fill"
        case "手电筒":
            return "flashlight.on.fill"
        case "绳子":
            return "lasso"
        default:
            return "shippingbox.fill"
        }
    }
}

// MARK: - Preview

#Preview("成功状态") {
    ExplorationResultView(result: MockExplorationData.explorationResult)
}

#Preview("错误状态") {
    ExplorationResultView(
        errorMessage: "网络连接失败，请检查网络设置后重试",
        onRetry: {
            print("重试探索")
        }
    )
}
