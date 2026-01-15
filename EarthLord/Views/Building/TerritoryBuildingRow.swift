//
//  TerritoryBuildingRow.swift
//  EarthLord
//
//  领地建筑行组件（在领地详情页显示建筑）
//

import SwiftUI

/// 领地建筑行组件
struct TerritoryBuildingRow: View {
    let building: PlayerBuilding
    let template: BuildingTemplate

    /// 升级回调
    var onUpgrade: (() -> Void)?

    /// 拆除回调
    var onDemolish: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：分类图标
            ZStack {
                Circle()
                    .fill(template.category.color.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: template.icon)
                    .font(.title3)
                    .foregroundColor(template.category.color)
            }

            // 中间：名称 + 状态
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 等级徽章
                    Text("Lv.\(building.level)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(4)

                    // MAX 标记（达到最高等级时显示）
                    if building.level >= template.maxLevel {
                        Text("MAX")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 8) {
                    // 状态徽章
                    Text(building.status.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(building.status.color)
                        .cornerRadius(4)

                    // 倒计时（建造中时显示）
                    if building.status == .constructing || building.status == .upgrading {
                        Text(building.formattedRemainingTime)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // 右侧：操作菜单或进度环
            if building.status == .active {
                // 操作菜单
                Menu {
                    // 升级按钮
                    if building.level >= template.maxLevel {
                        Button {} label: {
                            Label("已达最高等级", systemImage: "checkmark.circle.fill")
                        }
                        .disabled(true)
                    } else {
                        Button {
                            onUpgrade?()
                        } label: {
                            Label("升级", systemImage: "arrow.up.circle")
                        }
                    }

                    // 拆除按钮
                    Button(role: .destructive) {
                        onDemolish?()
                    } label: {
                        Label("拆除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            } else if building.status == .constructing || building.status == .upgrading {
                // 进度环
                CircularProgressView(progress: building.buildProgress)
                    .frame(width: 36, height: 36)
            }
        }
    }
}

/// 圆形进度视图
struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            // 背景圆
            Circle()
                .stroke(ApocalypseTheme.background, lineWidth: 4)

            // 进度圆
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)

            // 百分比文字
            Text("\(Int(progress * 100))%")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        TerritoryBuildingRow(
            building: PlayerBuilding(
                id: UUID(),
                userId: UUID(),
                territoryId: "test",
                templateId: "campfire",
                buildingName: "篝火",
                status: .active,
                level: 1,
                locationLat: 31.23,
                locationLon: 121.47,
                buildStartedAt: Date().addingTimeInterval(-30),
                buildCompletedAt: Date().addingTimeInterval(30),
                createdAt: Date(),
                updatedAt: Date()
            ),
            template: BuildingTemplate(
                id: "campfire",
                templateId: "campfire",
                name: "篝火",
                tier: 1,
                category: .survival,
                description: "简单的篝火",
                icon: "flame.fill",
                requiredResources: ["木材": 30],
                buildTimeSeconds: 60,
                maxPerTerritory: 3,
                maxLevel: 5
            ),
            onUpgrade: { print("升级") },
            onDemolish: { print("拆除") }
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
