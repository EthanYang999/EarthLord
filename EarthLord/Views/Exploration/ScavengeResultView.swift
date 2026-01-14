//
//  ScavengeResultView.swift
//  EarthLord
//
//  Created for Day22 POI Scavenging System
//
//  搜刮结果视图
//  显示玩家从 POI 搜刮获得的物品
//

import SwiftUI

/// 搜刮结果视图
struct ScavengeResultView: View {

    /// POI 名称
    let poiName: String

    /// 获得的物品列表
    let items: [GeneratedRewardItem]

    /// 确认回调
    let onConfirm: () -> Void

    /// 物品定义（用于显示图标）
    @StateObject private var inventoryManager = InventoryManager.shared

    /// 是否有 AI 生成的物品
    private var hasAIItems: Bool {
        items.contains { $0.isAIGenerated }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题
            VStack(spacing: 8) {
                // 成功图标 - AI 物品显示特殊图标
                if hasAIItems {
                    Image(systemName: "sparkles")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(ApocalypseTheme.success)
                }

                Text(hasAIItems ? "发现独特物品！" : "搜刮成功！")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(hasAIItems ? .purple : ApocalypseTheme.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text(poiName)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .font(.subheadline)
            }
            .padding(.top, 30)
            .padding(.bottom, 20)

            // 分割线
            Divider()
                .background(Color.gray.opacity(0.3))

            // 物品列表
            ScrollView {
                VStack(spacing: 12) {
                    Text("获得物品")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 16)

                    ForEach(items, id: \.itemId) { item in
                        ItemRowView(item: item)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            // 底部确认按钮
            Button(action: onConfirm) {
                Text("确认")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(ApocalypseTheme.background)
    }
}

// MARK: - Item Row View

/// 物品行视图
struct ItemRowView: View {

    let item: GeneratedRewardItem

    @StateObject private var inventoryManager = InventoryManager.shared

    /// AI 故事展开状态
    @State private var isStoryExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 主要内容行
            HStack(spacing: 12) {
                // 物品图标
                itemIcon
                    .frame(width: 50, height: 50)
                    .background(itemIconBackground)
                    .cornerRadius(10)

                // 物品信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.itemName)
                            .font(.headline)
                            .foregroundColor(item.isAIGenerated ? .purple : ApocalypseTheme.textPrimary)

                        // AI 徽章
                        if item.isAIGenerated {
                            aiBadge
                        }
                    }

                    HStack(spacing: 8) {
                        // 稀有度
                        Text(item.rarity)
                            .font(.caption)
                            .foregroundColor(rarityColor)

                        // 品质
                        if let quality = item.quality {
                            Text(qualityDisplayName(quality))
                                .font(.caption)
                                .foregroundColor(qualityColor(quality))
                        }

                        // 展开故事提示
                        if item.isAIGenerated && item.aiStory != nil {
                            Spacer()
                            Image(systemName: isStoryExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.purple.opacity(0.7))
                        }
                    }
                }

                Spacer()

                // 数量
                Text("x\(item.quantity)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.success)
            }
            .padding(12)

            // AI 故事展开区域
            if item.isAIGenerated && isStoryExpanded, let story = item.aiStory {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(Color.purple.opacity(0.3))

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "book.fill")
                            .font(.caption)
                            .foregroundColor(.purple.opacity(0.7))

                        Text(story)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(cardBorderOverlay)
        .onTapGesture {
            if item.isAIGenerated && item.aiStory != nil {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isStoryExpanded.toggle()
                }
            }
        }
    }

    // MARK: - AI 特效视图

    /// 物品图标背景
    @ViewBuilder
    private var itemIconBackground: some View {
        if item.isAIGenerated {
            LinearGradient(
                colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            rarityColor.opacity(0.2)
        }
    }

    /// 卡片边框
    @ViewBuilder
    private var cardBorderOverlay: some View {
        if item.isAIGenerated {
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [.purple, .pink.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        } else {
            RoundedRectangle(cornerRadius: 12)
                .stroke(rarityColor.opacity(0.3), lineWidth: 1)
        }
    }

    /// AI 徽章
    private var aiBadge: some View {
        Text("AI")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [.purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(4)
    }

    // MARK: - Private Properties

    /// 物品图标
    private var itemIcon: some View {
        let definition = inventoryManager.getItemDefinition(by: item.itemId)
        let category = definition?.category ?? "misc"

        return Image(systemName: categoryIcon(category))
            .font(.title2)
            .foregroundColor(rarityColor)
    }

    /// 稀有度颜色
    private var rarityColor: Color {
        switch item.rarity {
        case "common":
            return .gray
        case "uncommon":
            return .green
        case "rare":
            return .blue
        case "epic":
            return .purple
        case "legendary":
            return .orange
        default:
            return .gray
        }
    }

    // MARK: - Helper Methods

    /// 根据分类返回图标
    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "water":
            return "drop.fill"
        case "food":
            return "fork.knife"
        case "medical":
            return "cross.case.fill"
        case "material":
            return "cube.fill"
        case "tool":
            return "wrench.fill"
        case "weapon":
            return "hammer.fill"
        case "clothing":
            return "tshirt.fill"
        default:
            return "shippingbox.fill"
        }
    }

    /// 品质显示名称
    private func qualityDisplayName(_ quality: String) -> String {
        switch quality {
        case "broken":
            return "破损"
        case "worn":
            return "磨损"
        case "normal":
            return "普通"
        case "good":
            return "良好"
        case "pristine":
            return "完好"
        default:
            return quality
        }
    }

    /// 品质颜色
    private func qualityColor(_ quality: String) -> Color {
        switch quality {
        case "broken":
            return .red
        case "worn":
            return .orange
        case "normal":
            return .gray
        case "good":
            return .green
        case "pristine":
            return .cyan
        default:
            return .gray
        }
    }
}

// MARK: - Preview

#Preview("普通搜刮") {
    ScavengeResultView(
        poiName: "沃尔玛超市",
        items: [
            GeneratedRewardItem(
                itemId: UUID(),
                itemName: "矿泉水",
                quantity: 2,
                quality: "normal",
                rarity: "common"
            ),
            GeneratedRewardItem(
                itemId: UUID(),
                itemName: "罐头食品",
                quantity: 1,
                quality: "good",
                rarity: "uncommon"
            ),
            GeneratedRewardItem(
                itemId: UUID(),
                itemName: "绷带",
                quantity: 3,
                quality: "worn",
                rarity: "common"
            )
        ],
        onConfirm: { print("确认") }
    )
}

#Preview("AI 物品") {
    ScavengeResultView(
        poiName: "废弃医院",
        items: [
            GeneratedRewardItem(
                itemId: UUID(),
                itemName: "老陈的止痛药",
                quantity: 1,
                quality: "pristine",
                rarity: "epic",
                isAIGenerated: true,
                aiStory: "这瓶止痛药的标签上写着「老陈专用，别动」。老陈是这家医院的门卫，在末日来临前一天，他还在为自己的腰疼发愁。现在，这些药终于派上了用场——虽然不是给老陈。"
            ),
            GeneratedRewardItem(
                itemId: UUID(),
                itemName: "矿泉水",
                quantity: 2,
                quality: "normal",
                rarity: "common"
            ),
            GeneratedRewardItem(
                itemId: UUID(),
                itemName: "「最后的希望」急救包",
                quantity: 1,
                quality: "pristine",
                rarity: "legendary",
                isAIGenerated: true,
                aiStory: "急救包上贴着一张便条：「给找到这个的人——如果世界还没完蛋，记得帮我喂猫。钥匙在门垫下。——张医生」"
            )
        ],
        onConfirm: { print("确认") }
    )
}
