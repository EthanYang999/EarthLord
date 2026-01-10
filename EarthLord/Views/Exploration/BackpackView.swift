//
//  BackpackView.swift
//  EarthLord
//
//  Created on 2025/1/8.
//
//  背包管理页面
//  显示玩家持有的物品，支持搜索和分类筛选
///Users/ethan/Desktop/EarthLord/EarthLord/Views/Exploration/BackpackView.swift

import SwiftUI

struct BackpackView: View {

    // MARK: - State

    /// 搜索关键词
    @State private var searchText = ""

    /// 当前选中的分类筛选（nil表示全部）
    @State private var selectedCategory: ItemCategory? = nil

    /// 背包最大容量（用于演示）
    private let maxCapacity: Double = 100.0

    // MARK: - Computed Properties

    /// 当前背包使用的容量
    private var usedCapacity: Double {
        MockExplorationData.calculateTotalWeight()
    }

    /// 容量使用百分比
    private var capacityPercentage: Double {
        usedCapacity / maxCapacity
    }

    /// 进度条颜色
    private var capacityColor: Color {
        if capacityPercentage > 0.9 {
            return ApocalypseTheme.danger
        } else if capacityPercentage > 0.7 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.success
        }
    }

    /// 筛选后的物品列表
    private var filteredItems: [(item: InventoryItem, definition: ItemDefinition)] {
        var result: [(item: InventoryItem, definition: ItemDefinition)] = []

        for item in MockExplorationData.inventoryItems {
            guard let definition = MockExplorationData.getItemDefinition(by: item.definitionId) else {
                continue
            }

            // 分类筛选
            if let category = selectedCategory, definition.category != category {
                continue
            }

            // 搜索筛选
            if !searchText.isEmpty {
                if !definition.name.localizedCaseInsensitiveContains(searchText) {
                    continue
                }
            }

            result.append((item, definition))
        }

        return result
    }

    /// 筛选分类列表
    private let filterCategories: [ItemCategory?] = [
        nil,            // 全部
        .food,
        .water,
        .material,
        .tool,
        .medical
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // 容量状态卡
                        capacityCard

                        // 搜索和筛选
                        searchAndFilter

                        // 物品列表
                        itemList
                    }
                    .padding()
                }
            }
            .navigationTitle("背包")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(ApocalypseTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Subviews

    /// 容量状态卡
    private var capacityCard: some View {
        VStack(spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: "bag.fill")
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("背包容量")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 容量数值
                Text(String(format: "%.1f / %.0f kg", usedCapacity, maxCapacity))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(capacityColor)
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ApocalypseTheme.background)
                        .frame(height: 12)

                    // 进度
                    RoundedRectangle(cornerRadius: 6)
                        .fill(capacityColor)
                        .frame(
                            width: geometry.size.width * min(capacityPercentage, 1.0),
                            height: 12
                        )
                }
            }
            .frame(height: 12)

            // 警告文字
            if capacityPercentage > 0.9 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)

                    Text("背包快满了！")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(ApocalypseTheme.danger)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 搜索和筛选区域
    private var searchAndFilter: some View {
        VStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ApocalypseTheme.textMuted)

                TextField("搜索物品...", text: $searchText)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }
            .padding(12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)

            // 分类筛选按钮
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(filterCategories, id: \.self) { category in
                        CategoryFilterChip(
                            category: category,
                            isSelected: selectedCategory == category,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCategory = category
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    /// 物品列表
    private var itemList: some View {
        LazyVStack(spacing: 12) {
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                ForEach(filteredItems, id: \.item.id) { itemData in
                    ItemCard(
                        item: itemData.item,
                        definition: itemData.definition
                    )
                }
            }
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("没有找到物品")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("尝试调整筛选条件或搜索关键词")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - 分类筛选芯片

struct CategoryFilterChip: View {
    let category: ItemCategory?
    let isSelected: Bool
    let action: () -> Void

    /// 获取显示文字
    private var displayText: String {
        guard let category = category else { return "全部" }
        return category.rawValue
    }

    /// 获取图标
    private var iconName: String {
        guard let category = category else { return "square.grid.2x2" }
        return ItemCategoryStyle.icon(for: category)
    }

    /// 获取颜色
    private var color: Color {
        guard let category = category else { return ApocalypseTheme.primary }
        return ItemCategoryStyle.color(for: category)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.caption)

                Text(displayText)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? color
                    : ApocalypseTheme.cardBackground
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? color : ApocalypseTheme.textMuted.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - 物品卡片

struct ItemCard: View {
    let item: InventoryItem
    let definition: ItemDefinition

    var body: some View {
        HStack(spacing: 12) {
            // 左侧圆形图标
            itemIcon

            // 中间信息
            VStack(alignment: .leading, spacing: 6) {
                // 第一行：名称和数量
                HStack(spacing: 8) {
                    Text(definition.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("x\(item.quantity)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // 第二行：重量、品质、稀有度
                HStack(spacing: 8) {
                    // 重量
                    Label(
                        String(format: "%.1fkg", definition.weight * Double(item.quantity)),
                        systemImage: "scalemass"
                    )
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                    // 品质（如有）
                    if let quality = item.quality {
                        QualityBadge(quality: quality)
                    }

                    // 稀有度标签
                    RarityBadge(rarity: definition.rarity)
                }
            }

            Spacer()

            // 右侧操作按钮
            actionButtons
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 物品图标
    private var itemIcon: some View {
        ZStack {
            Circle()
                .fill(ItemCategoryStyle.color(for: definition.category).opacity(0.2))
                .frame(width: 50, height: 50)

            Image(systemName: ItemCategoryStyle.icon(for: definition.category))
                .font(.title2)
                .foregroundColor(ItemCategoryStyle.color(for: definition.category))
        }
    }

    /// 操作按钮
    private var actionButtons: some View {
        VStack(spacing: 6) {
            // 使用按钮
            Button {
                print("使用物品: \(definition.name)")
            } label: {
                Text("使用")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(6)
            }

            // 存储按钮
            Button {
                print("存储物品: \(definition.name)")
            } label: {
                Text("存储")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ApocalypseTheme.background)
                    .cornerRadius(6)
            }
        }
    }
}

// MARK: - 品质徽章

struct QualityBadge: View {
    let quality: ItemQuality

    /// 品质颜色
    private var color: Color {
        switch quality {
        case .broken:
            return ApocalypseTheme.danger
        case .worn:
            return ApocalypseTheme.warning
        case .normal:
            return ApocalypseTheme.textSecondary
        case .good:
            return ApocalypseTheme.success
        case .pristine:
            return ApocalypseTheme.info
        }
    }

    var body: some View {
        Text(quality.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
}

// MARK: - 稀有度徽章

struct RarityBadge: View {
    let rarity: ItemRarity

    /// 稀有度颜色
    private var color: Color {
        switch rarity {
        case .common:
            return .gray           // 普通：灰色
        case .uncommon:
            return .green          // 优秀：绿色
        case .rare:
            return .blue           // 稀有：蓝色
        case .epic:
            return .purple         // 史诗：紫色
        case .legendary:
            return .orange         // 传说：橙色
        }
    }

    var body: some View {
        Text(rarity.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
}

// MARK: - 物品分类样式

enum ItemCategoryStyle {

    /// 获取分类图标
    static func icon(for category: ItemCategory) -> String {
        switch category {
        case .water:
            return "drop.fill"
        case .food:
            return "fork.knife"
        case .medical:
            return "cross.case.fill"
        case .material:
            return "cube.box.fill"
        case .tool:
            return "wrench.and.screwdriver.fill"
        case .weapon:
            return "scope"
        case .clothing:
            return "tshirt.fill"
        case .misc:
            return "ellipsis.circle.fill"
        }
    }

    /// 获取分类颜色
    static func color(for category: ItemCategory) -> Color {
        switch category {
        case .water:
            return .cyan
        case .food:
            return .orange
        case .medical:
            return .red
        case .material:
            return .brown
        case .tool:
            return .gray
        case .weapon:
            return .red
        case .clothing:
            return .indigo
        case .misc:
            return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    BackpackView()
}
