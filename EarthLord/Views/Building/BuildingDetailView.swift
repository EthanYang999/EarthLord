//
//  BuildingDetailView.swift
//  EarthLord
//
//  建筑详情页
//  显示建筑完整信息，提供开始建造入口
//

import SwiftUI

/// 建筑详情页
struct BuildingDetailView: View {
    // MARK: - Properties

    let template: BuildingTemplate
    let onDismiss: () -> Void
    let onStartConstruction: () -> Void

    @ObservedObject private var inventoryManager = InventoryManager.shared

    // MARK: - Computed Properties

    /// 资源状态列表
    private var resourceStatus: [(name: String, required: Int, available: Int)] {
        template.requiredResources.map { (name, required) in
            let available = getResourceCount(name: name)
            return (name: name, required: required, available: available)
        }
    }

    /// 是否资源充足
    private var hasEnoughResources: Bool {
        resourceStatus.allSatisfy { $0.available >= $0.required }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 建筑头部
                        buildingHeader

                        // 描述
                        descriptionSection

                        // 所需资源
                        resourcesSection

                        // 建造时间
                        buildTimeSection

                        // 开始建造按钮
                        startButton
                    }
                    .padding()
                }
            }
            .navigationTitle("建筑详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        onDismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }
        }
    }

    // MARK: - Subviews

    /// 建筑头部
    private var buildingHeader: some View {
        VStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(template.category.color.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: template.icon)
                    .font(.system(size: 40))
                    .foregroundColor(template.category.color)
            }

            // 名称
            Text(template.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 分类和等级
            HStack(spacing: 12) {
                Label(template.category.displayName, systemImage: template.category.icon)
                    .font(.subheadline)
                    .foregroundColor(template.category.color)

                Text("Tier \(template.tier)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 描述区域
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("建筑描述", systemImage: "text.alignleft")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(template.description)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 资源区域
    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("所需资源", systemImage: "cube.box")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            VStack(spacing: 8) {
                ForEach(resourceStatus, id: \.name) { item in
                    ResourceRow(
                        resourceName: item.name,
                        required: item.required,
                        available: item.available
                    )
                }
            }

            if !hasEnoughResources {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(ApocalypseTheme.danger)
                    Text("资源不足，无法建造")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.danger)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 建造时间区域
    private var buildTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("建造时间", systemImage: "clock")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(template.formattedBuildTime)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 开始建造按钮
    private var startButton: some View {
        Button {
            onStartConstruction()
        } label: {
            HStack {
                Image(systemName: "hammer.fill")
                Text("开始建造")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(ApocalypseTheme.primary)
            .cornerRadius(12)
        }
    }

    // MARK: - Methods

    /// 获取资源数量
    private func getResourceCount(name: String) -> Int {
        guard let itemDef = inventoryManager.getItemDefinition(byName: name) else {
            return 0
        }

        return inventoryManager.inventoryItems
            .filter { $0.itemId == itemDef.id }
            .reduce(0) { $0 + $1.quantity }
    }
}

#Preview {
    BuildingDetailView(
        template: BuildingTemplate(
            id: "campfire",
            templateId: "campfire",
            name: "篝火",
            tier: 1,
            category: .survival,
            description: "简单的篝火，提供照明和取暖。末世的第一个夜晚，你需要它。",
            icon: "flame.fill",
            requiredResources: ["木材": 30, "石头": 20],
            buildTimeSeconds: 30,
            maxPerTerritory: 3,
            maxLevel: 5
        ),
        onDismiss: {},
        onStartConstruction: {}
    )
}
