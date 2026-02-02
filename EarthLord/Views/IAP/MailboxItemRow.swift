//
//  MailboxItemRow.swift
//  EarthLord
//
//  邮箱物品行组件
//

import SwiftUI

struct MailboxItemRow: View {
    let item: DBMailboxItem
    let onClaim: () -> Void

    @State private var isClaiming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：来源类型、标题、时间
            HStack(spacing: 8) {
                // 来源图标
                ZStack {
                    Circle()
                        .fill(sourceColor.opacity(0.2))
                        .frame(width: 36, height: 36)

                    Image(systemName: item.sourceTypeEnum.icon)
                        .font(.system(size: 16))
                        .foregroundColor(sourceColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    // 来源类型标签
                    Text(item.sourceTypeEnum.displayName)
                        .font(.caption2)
                        .foregroundColor(sourceColor)

                    // 标题
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                Spacer()

                // 时间
                Text(item.formattedDate)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 物品列表预览
            itemsPreview

            // 底部：状态和操作
            HStack {
                if item.isClaimed {
                    // 已领取状态
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("已领取")
                            .font(.caption)
                    }
                    .foregroundColor(ApocalypseTheme.textMuted)
                } else {
                    Spacer()

                    // 领取按钮
                    Button(action: {
                        isClaiming = true
                        onClaim()
                    }) {
                        HStack(spacing: 6) {
                            if isClaiming {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.down.to.line")
                                    .font(.caption)
                            }
                            Text("领取")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(10)
                    }
                    .disabled(isClaiming)
                }
            }
        }
        .padding()
        .background(item.isClaimed ? ApocalypseTheme.cardBackground.opacity(0.5) : ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    item.isClaimed ? Color.clear : sourceColor.opacity(0.3),
                    lineWidth: 1
                )
        )
    }

    // MARK: - 物品预览

    private var itemsPreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(item.items) { reward in
                    rewardBadge(reward)
                }
            }
        }
    }

    private func rewardBadge(_ reward: MailboxReward) -> some View {
        HStack(spacing: 4) {
            Image(systemName: itemIcon(for: reward.itemName))
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.primary)

            Text(reward.itemName)
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("x\(reward.quantity)")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(ApocalypseTheme.background)
        .cornerRadius(6)
    }

    // MARK: - Helpers

    private var sourceColor: Color {
        switch item.sourceTypeEnum {
        case .purchase: return ApocalypseTheme.primary
        case .reward: return Color.yellow
        case .system: return Color.blue
        case .trade: return Color.green
        case .event: return Color.purple
        }
    }

    private func itemIcon(for itemName: String) -> String {
        switch itemName.lowercased() {
        case "water": return "drop.fill"
        case "food": return "leaf.fill"
        case "bandage": return "cross.case.fill"
        case "medical_kit": return "cross.case.fill"
        case "flashlight": return "flashlight.on.fill"
        case "wood": return "tree.fill"
        case "stone": return "mountain.2.fill"
        case "metal": return "gearshape.fill"
        default: return "cube.fill"
        }
    }
}

#Preview {
    let mockItem = DBMailboxItem(
        id: UUID(),
        userId: UUID(),
        sourceType: "purchase",
        sourceId: UUID(),
        title: "幸存者补给包",
        items: [
            MailboxReward(itemName: "water", quantity: 5),
            MailboxReward(itemName: "food", quantity: 5),
            MailboxReward(itemName: "bandage", quantity: 2)
        ],
        isClaimed: false,
        claimedAt: nil,
        createdAt: Date()
    )

    return VStack {
        MailboxItemRow(item: mockItem) {
            print("Claim tapped")
        }

        MailboxItemRow(item: DBMailboxItem(
            id: UUID(),
            userId: UUID(),
            sourceType: "purchase",
            sourceId: UUID(),
            title: "探索者物资包",
            items: [
                MailboxReward(itemName: "water", quantity: 15),
                MailboxReward(itemName: "food", quantity: 15)
            ],
            isClaimed: true,
            claimedAt: Date(),
            createdAt: Date().addingTimeInterval(-3600)
        )) {
            print("Claim tapped")
        }
    }
    .padding()
    .background(ApocalypseTheme.background)
}
