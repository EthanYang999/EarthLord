//
//  SupplyPackCard.swift
//  EarthLord
//
//  物资包卡片组件
//

import SwiftUI
import StoreKit

struct SupplyPackCard: View {
    let pack: DBSupplyPackDefinition
    let product: Product?
    let onPurchase: () -> Void

    @ObservedObject private var iapManager = IAPManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：图标和名称
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(tierGradient)
                        .frame(width: 50, height: 50)

                    Image(systemName: pack.icon ?? "gift")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // 等级标签
                    Text(tierLabel)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(tierColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(tierColor.opacity(0.2))
                        .cornerRadius(4)

                    // 名称
                    Text(pack.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                Spacer()

                // 价格按钮
                purchaseButton
            }

            // 描述
            if let description = pack.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineLimit(2)
            }

            // 物品列表
            itemsPreview
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tierColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 购买按钮

    private var purchaseButton: some View {
        Button(action: onPurchase) {
            Group {
                if case .purchasing(let productId) = iapManager.purchaseState,
                   productId == pack.productId {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 20, height: 20)
                } else if let product = product {
                    Text(product.displayPrice)
                        .font(.subheadline)
                        .fontWeight(.bold)
                } else {
                    Text("¥\(Int(pack.priceCny))")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
            }
            .foregroundColor(.white)
            .frame(minWidth: 70)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [tierColor, tierColor.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(10)
        }
        .disabled(iapManager.purchaseState != .idle || product == nil)
    }

    // MARK: - 物品预览

    private var itemsPreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pack.items) { item in
                    itemBadge(item)
                }
            }
        }
    }

    private func itemBadge(_ item: SupplyPackItem) -> some View {
        HStack(spacing: 4) {
            Image(systemName: itemIcon(for: item.itemName))
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.primary)

            Text("\(item.itemName)")
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("x\(item.quantity)")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(ApocalypseTheme.background)
        .cornerRadius(6)
    }

    // MARK: - Helper Properties

    private var tierGradient: LinearGradient {
        LinearGradient(
            colors: [tierColor, tierColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var tierColor: Color {
        switch pack.tier {
        case 1: return Color.gray
        case 2: return Color.green
        case 3: return Color.blue
        case 4: return Color.orange
        default: return Color.gray
        }
    }

    private var tierLabel: String {
        switch pack.tier {
        case 1: return "STARTER"
        case 2: return "POPULAR"
        case 3: return "VALUE"
        case 4: return "BEST"
        default: return ""
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
    let mockPack = DBSupplyPackDefinition(
        id: UUID(),
        productId: "com.earthlord.supply.survivor",
        name: "幸存者补给包",
        description: "基础生存物资，适合新手幸存者",
        icon: "gift",
        tier: 1,
        priceCny: 6.0,
        items: [
            SupplyPackItem(itemName: "water", quantity: 5),
            SupplyPackItem(itemName: "food", quantity: 5),
            SupplyPackItem(itemName: "bandage", quantity: 2)
        ],
        isActive: true,
        createdAt: Date()
    )

    return SupplyPackCard(pack: mockPack, product: nil) {
        print("Purchase tapped")
    }
    .padding()
    .background(ApocalypseTheme.background)
}
