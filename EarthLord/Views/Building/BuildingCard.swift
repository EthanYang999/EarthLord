//
//  BuildingCard.swift
//  EarthLord
//
//  建筑卡片组件（用于建筑浏览网格）
//

import SwiftUI

/// 建筑卡片组件
struct BuildingCard: View {
    let template: BuildingTemplate
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(template.category.color.opacity(0.2))
                        .frame(width: 56, height: 56)

                    Image(systemName: template.icon)
                        .font(.system(size: 26))
                        .foregroundColor(template.category.color)
                }

                // 名称
                Text(template.name)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                // 分类和等级
                HStack(spacing: 6) {
                    Text(template.category.displayName)
                        .font(.caption)
                        .foregroundColor(template.category.color)

                    Text("T\(template.tier)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ApocalypseTheme.background)
                        .cornerRadius(4)
                }

                // 建造时间
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(template.formattedBuildTime)
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(template.category.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        BuildingCard(
            template: BuildingTemplate(
                id: "campfire",
                templateId: "campfire",
                name: "篝火",
                tier: 1,
                category: .survival,
                description: "简单的篝火",
                icon: "flame.fill",
                requiredResources: ["木材": 30],
                buildTimeSeconds: 30,
                maxPerTerritory: 3,
                maxLevel: 5
            ),
            onTap: {}
        )
        BuildingCard(
            template: BuildingTemplate(
                id: "shelter",
                templateId: "shelter",
                name: "庇护所",
                tier: 1,
                category: .survival,
                description: "简易庇护所",
                icon: "house.fill",
                requiredResources: ["木材": 50, "石头": 30],
                buildTimeSeconds: 300,
                maxPerTerritory: 1,
                maxLevel: 3
            ),
            onTap: {}
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
