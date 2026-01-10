//
//  ResourcesTabView.swift
//  EarthLord
//
//  Created on 2025/1/8.
//
//  资源模块主入口页面
//  包含POI、背包、已购、领地资源、交易五个子模块
//

import SwiftUI

/// 资源分段类型
enum ResourceSegment: Int, CaseIterable {
    case poi = 0
    case backpack = 1
    case purchased = 2
    case territory = 3
    case trade = 4

    var title: String {
        switch self {
        case .poi: return "POI"
        case .backpack: return "背包"
        case .purchased: return "已购"
        case .territory: return "领地"
        case .trade: return "交易"
        }
    }
}

struct ResourcesTabView: View {

    // MARK: - State

    /// 当前选中的分段
    @State private var selectedSegment: ResourceSegment = .poi

    /// 交易开关状态（假数据）
    @State private var isTradeEnabled = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 分段选择器
                    segmentPicker
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // 内容区域
                    contentView
                }
            }
            .navigationTitle("资源")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(ApocalypseTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    tradeToggle
                }
            }
        }
    }

    // MARK: - Subviews

    /// 分段选择器
    private var segmentPicker: some View {
        Picker("资源分段", selection: $selectedSegment) {
            ForEach(ResourceSegment.allCases, id: \.self) { segment in
                Text(segment.title).tag(segment)
            }
        }
        .pickerStyle(.segmented)
    }

    /// 交易开关
    private var tradeToggle: some View {
        HStack(spacing: 6) {
            Text("交易")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Toggle("", isOn: $isTradeEnabled)
                .labelsHidden()
                .tint(ApocalypseTheme.primary)
                .scaleEffect(0.8)
        }
    }

    /// 内容区域
    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case .poi:
            POIContentView()

        case .backpack:
            BackpackContentView()

        case .purchased:
            placeholderView(
                icon: "bag.fill",
                title: "已购物品",
                subtitle: "功能开发中"
            )

        case .territory:
            placeholderView(
                icon: "flag.fill",
                title: "领地资源",
                subtitle: "功能开发中"
            )

        case .trade:
            placeholderView(
                icon: "arrow.triangle.2.circlepath",
                title: "交易市场",
                subtitle: "功能开发中"
            )
        }
    }

    /// 占位视图
    private func placeholderView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - POI内容视图（去除导航栏的版本）

struct POIContentView: View {

    @State private var displayedPOIs: [POI] = MockExplorationData.pois
    @State private var isSearching = false
    @State private var selectedFilter: POIType? = nil

    /// 搜索按钮缩放状态
    @State private var searchButtonScale: CGFloat = 1.0

    /// POI列表出现动画状态
    @State private var poiAppearStates: [String: Bool] = [:]

    private let mockCoordinate = (lat: 22.54, lon: 114.06)

    private var discoveredCount: Int {
        displayedPOIs.filter { $0.discoveryStatus != .undiscovered }.count
    }

    /// 是否有任何POI数据
    private var hasAnyPOIs: Bool {
        !MockExplorationData.pois.isEmpty
    }

    /// 是否是筛选导致的空结果
    private var isFilteredEmpty: Bool {
        selectedFilter != nil && displayedPOIs.isEmpty && hasAnyPOIs
    }

    private let filterTypes: [POIType?] = [nil, .hospital, .supermarket, .factory, .pharmacy, .gasStation]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 状态栏
                statusBar

                // 搜索按钮
                searchButton

                // 筛选工具栏
                filterToolbar

                // POI列表
                poiList
            }
            .padding()
        }
    }

    private var statusBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.success)

                Text(String(format: "%.2f, %.2f", mockCoordinate.lat, mockCoordinate.lon))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "eye.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("附近发现 \(discoveredCount) 个地点")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }

    private var searchButton: some View {
        Button {
            // 按下缩放动画
            withAnimation(.easeInOut(duration: 0.1)) {
                searchButtonScale = 0.95
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    searchButtonScale = 1.0
                }
            }

            isSearching = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isSearching = false
            }
        } label: {
            HStack(spacing: 12) {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                    Text("搜索中...")
                        .font(.headline)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.headline)
                    Text("搜索附近POI")
                        .font(.headline)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSearching ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
            .cornerRadius(12)
        }
        .scaleEffect(searchButtonScale)
        .disabled(isSearching)
    }

    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filterTypes, id: \.self) { type in
                    FilterChip(
                        type: type,
                        isSelected: selectedFilter == type,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedFilter = type
                                applyFilter()
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var poiList: some View {
        LazyVStack(spacing: 12) {
            if displayedPOIs.isEmpty {
                // 空状态
                emptyStateView
                    .transition(.opacity)
            } else {
                ForEach(Array(displayedPOIs.enumerated()), id: \.element.id) { index, poi in
                    NavigationLink(destination: POIDetailView(poi: poi)) {
                        POICard(poi: poi)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(poiAppearStates[poi.id] == true ? 1 : 0)
                    .offset(y: poiAppearStates[poi.id] == true ? 0 : 20)
                    .onAppear {
                        // 依次淡入动画，每个间隔0.1秒
                        withAnimation(.easeOut(duration: 0.3).delay(Double(index) * 0.1)) {
                            poiAppearStates[poi.id] = true
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: displayedPOIs.count)
    }

    /// 空状态视图
    @ViewBuilder
    private var emptyStateView: some View {
        if isFilteredEmpty {
            // 筛选后没有结果
            VStack(spacing: 16) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("没有找到该类型的地点")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("尝试选择其他分类")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else {
            // 完全没有POI
            VStack(spacing: 16) {
                Image(systemName: "map")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("附近暂无兴趣点")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("点击搜索按钮发现周围的废墟")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        }
    }

    private func applyFilter() {
        // 重置动画状态
        poiAppearStates.removeAll()

        if let filter = selectedFilter {
            displayedPOIs = MockExplorationData.pois.filter { $0.type == filter }
        } else {
            displayedPOIs = MockExplorationData.pois
        }
    }
}

// MARK: - 背包内容视图（去除导航栏的版本）

struct BackpackContentView: View {

    /// 背包管理器
    @ObservedObject private var inventoryManager = InventoryManager.shared

    @State private var searchText = ""
    @State private var selectedCategory: ItemCategory? = nil

    /// 动画显示的容量值
    @State private var animatedCapacity: Double = 0

    /// 物品出现动画状态
    @State private var itemAppearStates: [String: Bool] = [:]

    /// 是否已加载
    @State private var hasLoaded = false

    private let maxCapacity: Double = 100.0

    private var usedCapacity: Double {
        inventoryManager.calculateTotalWeight()
    }

    private var capacityPercentage: Double {
        usedCapacity / maxCapacity
    }

    private var capacityColor: Color {
        if capacityPercentage > 0.9 {
            return ApocalypseTheme.danger
        } else if capacityPercentage > 0.7 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.success
        }
    }

    /// 筛选后的物品列表（从数据库）
    private var filteredItems: [(item: DBInventoryItem, definition: DBItemDefinition)] {
        var result: [(item: DBInventoryItem, definition: DBItemDefinition)] = []
        for item in inventoryManager.inventoryItems {
            guard let definition = inventoryManager.getItemDefinition(by: item.itemId) else { continue }

            // 分类筛选
            if let category = selectedCategory {
                let dbCategory = categoryToDBCategory(category)
                if definition.category != dbCategory { continue }
            }

            // 搜索筛选
            if !searchText.isEmpty && !definition.name.localizedCaseInsensitiveContains(searchText) { continue }

            result.append((item, definition))
        }
        return result
    }

    /// 背包是否完全为空
    private var isBackpackEmpty: Bool {
        inventoryManager.inventoryItems.isEmpty
    }

    /// 是否是搜索/筛选导致的空结果
    private var isFilteredEmpty: Bool {
        !isBackpackEmpty && filteredItems.isEmpty && (!searchText.isEmpty || selectedCategory != nil)
    }

    private let filterCategories: [ItemCategory?] = [nil, .food, .water, .material, .tool, .medical]

    /// 动画进度条百分比
    private var animatedPercentage: Double {
        animatedCapacity / maxCapacity
    }

    /// 转换分类枚举到数据库字符串
    private func categoryToDBCategory(_ category: ItemCategory) -> String {
        switch category {
        case .water: return "water"
        case .food: return "food"
        case .medical: return "medical"
        case .material: return "material"
        case .tool: return "tool"
        case .weapon: return "weapon"
        case .clothing: return "clothing"
        case .misc: return "misc"
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    capacityCard
                    searchAndFilter
                    itemList
                }
                .padding()
            }

            // 加载中
            if inventoryManager.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
        .onAppear {
            if !hasLoaded {
                hasLoaded = true
                Task {
                    await inventoryManager.loadItemDefinitions()
                    await inventoryManager.loadInventory()
                    // 容量数值动画
                    withAnimation(.easeOut(duration: 0.8)) {
                        animatedCapacity = usedCapacity
                    }
                }
            }
        }
        .onChange(of: inventoryManager.inventoryItems) { _, _ in
            // 当背包更新时，更新容量动画
            withAnimation(.easeOut(duration: 0.5)) {
                animatedCapacity = usedCapacity
            }
        }
    }

    private var capacityCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "bag.fill")
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("背包容量")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 使用动画数值
                Text(String(format: "%.1f / %.0f kg", animatedCapacity, maxCapacity))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(capacityColor)
                    .contentTransition(.numericText())
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ApocalypseTheme.background)
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(capacityColor)
                        .frame(width: geometry.size.width * min(animatedPercentage, 1.0), height: 12)
                        .animation(.easeOut(duration: 0.8), value: animatedPercentage)
                }
            }
            .frame(height: 12)

            if capacityPercentage > 0.9 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text("背包快满了！")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(ApocalypseTheme.danger)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private var searchAndFilter: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ApocalypseTheme.textMuted)

                TextField("搜索物品...", text: $searchText)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }
            .padding(12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)

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

    private var itemList: some View {
        LazyVStack(spacing: 12) {
            if filteredItems.isEmpty {
                // 空状态
                backpackEmptyStateView
                    .transition(.opacity)
            } else {
                ForEach(Array(filteredItems.enumerated()), id: \.element.item.id) { index, itemData in
                    DBItemCard(item: itemData.item, definition: itemData.definition)
                        .opacity(itemAppearStates[itemData.item.id.uuidString] == true ? 1 : 0)
                        .offset(y: itemAppearStates[itemData.item.id.uuidString] == true ? 0 : 15)
                        .onAppear {
                            withAnimation(.easeOut(duration: 0.25).delay(Double(index) * 0.05)) {
                                itemAppearStates[itemData.item.id.uuidString] = true
                            }
                        }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedCategory)
        .onChange(of: selectedCategory) { _, _ in
            // 切换分类时重置动画状态
            itemAppearStates.removeAll()
        }
    }

    /// 背包空状态视图
    @ViewBuilder
    private var backpackEmptyStateView: some View {
        if isFilteredEmpty {
            // 搜索/筛选没有结果
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("没有找到相关物品")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("尝试调整筛选条件或搜索关键词")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else {
            // 背包完全为空
            VStack(spacing: 16) {
                Image(systemName: "bag")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("背包空空如也")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("去探索收集物资吧")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        }
    }
}

// MARK: - 数据库物品卡片

struct DBItemCard: View {
    let item: DBInventoryItem
    let definition: DBItemDefinition

    /// 分类颜色
    private var categoryColor: Color {
        switch definition.category {
        case "water": return .cyan
        case "food": return .orange
        case "medical": return .red
        case "material": return .brown
        case "tool": return .gray
        case "weapon": return .red
        case "clothing": return .indigo
        default: return .gray
        }
    }

    /// 分类图标
    private var categoryIcon: String {
        switch definition.category {
        case "water": return "drop.fill"
        case "food": return "fork.knife"
        case "medical": return "cross.case.fill"
        case "material": return "cube.box.fill"
        case "tool": return "wrench.and.screwdriver.fill"
        case "weapon": return "scope"
        case "clothing": return "tshirt.fill"
        default: return "ellipsis.circle.fill"
        }
    }

    /// 稀有度颜色
    private var rarityColor: Color {
        switch definition.rarity {
        case "common": return .gray
        case "uncommon": return .green
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .orange
        default: return .gray
        }
    }

    /// 稀有度显示名称
    private var rarityDisplayName: String {
        switch definition.rarity {
        case "common": return "普通"
        case "uncommon": return "少见"
        case "rare": return "稀有"
        case "epic": return "史诗"
        case "legendary": return "传说"
        default: return "普通"
        }
    }

    /// 品质显示名称
    private var qualityDisplayName: String? {
        guard let q = item.quality else { return nil }
        switch q {
        case "broken": return "破损"
        case "worn": return "磨损"
        case "normal": return "普通"
        case "good": return "良好"
        case "pristine": return "完好"
        default: return nil
        }
    }

    /// 品质颜色
    private var qualityColor: Color {
        guard let q = item.quality else { return .gray }
        switch q {
        case "broken": return ApocalypseTheme.danger
        case "worn": return ApocalypseTheme.warning
        case "normal": return ApocalypseTheme.textSecondary
        case "good": return ApocalypseTheme.success
        case "pristine": return ApocalypseTheme.info
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 左侧圆形图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: definition.icon ?? categoryIcon)
                    .font(.title2)
                    .foregroundColor(categoryColor)
            }

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
                    if let qualityName = qualityDisplayName {
                        Text(qualityName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(qualityColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(qualityColor.opacity(0.15))
                            .cornerRadius(4)
                    }

                    // 稀有度标签
                    Text(rarityDisplayName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(rarityColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rarityColor.opacity(0.15))
                        .cornerRadius(4)
                }
            }

            Spacer()

            // 右侧操作按钮
            VStack(spacing: 6) {
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
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    ResourcesTabView()
}
