//
//  POIDetailView.swift
//  EarthLord
//
//  Created on 2025/1/8.
//
//  POI详情页面
//  显示兴趣点的详细信息和操作选项
//

import SwiftUI

struct POIDetailView: View {

    // MARK: - Properties

    /// 当前显示的POI
    let poi: POI

    // MARK: - State

    /// 是否正在搜寻
    @State private var isExploring = false

    /// 是否显示探索结果
    @State private var showExplorationResult = false

    // MARK: - Computed Properties

    /// POI类型颜色
    private var typeColor: Color {
        POITypeStyle.color(for: poi.type)
    }

    /// POI类型图标
    private var typeIcon: String {
        POITypeStyle.icon(for: poi.type)
    }

    /// 是否可以搜寻
    private var canExplore: Bool {
        poi.discoveryStatus == .discovered && poi.resourceStatus == .hasResources
    }

    /// 危险等级信息
    private var dangerInfo: (text: String, color: Color) {
        switch poi.dangerLevel {
        case 1:
            return ("安全", ApocalypseTheme.success)
        case 2:
            return ("低危", Color.green)
        case 3:
            return ("中危", ApocalypseTheme.warning)
        case 4:
            return ("高危", Color.orange)
        default:
            return ("极危", ApocalypseTheme.danger)
        }
    }

    /// 模拟距离（假数据）
    private let mockDistance: Int = 350

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 顶部大图区域
                    headerSection

                    // 内容区域
                    VStack(spacing: 16) {
                        // 信息卡片
                        infoCard

                        // 操作按钮
                        actionButtons
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showExplorationResult) {
            ExplorationResultView(result: MockExplorationData.explorationResult)
        }
    }

    // MARK: - Header Section

    /// 顶部大图区域
    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // 渐变背景
            LinearGradient(
                gradient: Gradient(colors: [
                    typeColor,
                    typeColor.opacity(0.6),
                    ApocalypseTheme.background
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)

            // 中间大图标
            VStack {
                Spacer()

                Image(systemName: typeIcon)
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

                Spacer()
            }
            .frame(height: 200)

            // 底部遮罩和文字
            VStack(spacing: 8) {
                Text(poi.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    // 类型标签
                    Label(poi.type.rawValue, systemImage: typeIcon)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))

                    // 发现状态
                    if poi.discoveryStatus != .undiscovered {
                        Text("已发现")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .black.opacity(0.6)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - Info Card

    /// 信息卡片
    private var infoCard: some View {
        VStack(spacing: 0) {
            // 距离
            infoRow(
                icon: "location.fill",
                iconColor: ApocalypseTheme.info,
                title: "距离",
                value: "\(mockDistance) 米"
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 物资状态
            infoRow(
                icon: resourceStatusIcon,
                iconColor: resourceStatusColor,
                title: "物资状态",
                value: resourceStatusText,
                valueColor: resourceStatusColor
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 危险等级
            infoRow(
                icon: "exclamationmark.shield.fill",
                iconColor: dangerInfo.color,
                title: "危险等级",
                value: dangerInfo.text,
                valueColor: dangerInfo.color
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 来源
            infoRow(
                icon: "doc.text.fill",
                iconColor: ApocalypseTheme.textSecondary,
                title: "来源",
                value: "地图数据"
            )
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 信息行
    private func infoRow(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        valueColor: Color = ApocalypseTheme.textPrimary
    ) -> some View {
        HStack {
            // 图标
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(iconColor)
                .frame(width: 30)

            // 标题
            Text(title)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            // 值
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
        .padding()
    }

    /// 物资状态图标
    private var resourceStatusIcon: String {
        switch poi.resourceStatus {
        case .hasResources:
            return "cube.box.fill"
        case .empty:
            return "cube.box"
        case .unknown:
            return "questionmark.circle"
        }
    }

    /// 物资状态颜色
    private var resourceStatusColor: Color {
        switch poi.resourceStatus {
        case .hasResources:
            return ApocalypseTheme.warning
        case .empty:
            return ApocalypseTheme.textMuted
        case .unknown:
            return ApocalypseTheme.textSecondary
        }
    }

    /// 物资状态文字
    private var resourceStatusText: String {
        switch poi.resourceStatus {
        case .hasResources:
            return "有物资"
        case .empty:
            return "已清空"
        case .unknown:
            return "未知"
        }
    }

    // MARK: - Action Buttons

    /// 操作按钮区域
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 主按钮 - 搜寻此POI
            Button {
                startExploration()
            } label: {
                HStack(spacing: 12) {
                    if isExploring {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)

                        Text("搜寻中...")
                            .font(.headline)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.headline)

                        Text("搜寻此POI")
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    canExplore
                        ? LinearGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.textMuted,
                                ApocalypseTheme.textMuted
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                )
                .cornerRadius(12)
            }
            .disabled(!canExplore || isExploring)

            // 不可搜寻时的提示
            if !canExplore {
                Text(poi.resourceStatus == .empty ? "该地点已被搜空" : "请先发现此地点")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 两个小按钮
            HStack(spacing: 12) {
                // 标记已发现
                SecondaryActionButton(
                    icon: "eye.fill",
                    title: "标记已发现",
                    isActive: poi.discoveryStatus != .undiscovered
                ) {
                    print("标记已发现: \(poi.name)")
                }

                // 标记无物资
                SecondaryActionButton(
                    icon: "cube.box",
                    title: "标记无物资",
                    isActive: poi.resourceStatus == .empty
                ) {
                    print("标记无物资: \(poi.name)")
                }
            }
        }
    }

    // MARK: - Methods

    /// 开始搜寻
    private func startExploration() {
        isExploring = true

        // 模拟搜寻过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isExploring = false
            showExplorationResult = true
        }
    }
}

// MARK: - 次要操作按钮

struct SecondaryActionButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(
                isActive
                    ? ApocalypseTheme.primary
                    : ApocalypseTheme.textSecondary
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isActive
                            ? ApocalypseTheme.primary.opacity(0.5)
                            : ApocalypseTheme.textMuted.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - Preview

#Preview("有物资") {
    POIDetailView(poi: MockExplorationData.pois[0])
}

#Preview("已搜空") {
    POIDetailView(poi: MockExplorationData.pois[1])
}

#Preview("未发现") {
    POIDetailView(poi: MockExplorationData.pois[2])
}
