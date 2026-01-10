//
//  POIListView.swift
//  EarthLord
//
//  Created on 2025/1/8.
//
//  附近兴趣点列表页面
//  显示玩家周围可探索的地点
//

import SwiftUI
import CoreLocation

struct POIListView: View {

    // MARK: - Environment

    /// 位置管理器
    @EnvironmentObject var locationManager: LocationManager

    // MARK: - Observed Objects

    /// POI统一管理器
    @ObservedObject private var poiManager = POIManager.shared

    // MARK: - State

    /// 当前选中的筛选类型（nil表示全部）
    @State private var selectedFilter: POIType? = nil

    /// 是否已执行过搜索
    @State private var hasSearched = false

    // MARK: - Computed Properties

    /// 当前用户坐标
    private var userCoordinate: CLLocationCoordinate2D? {
        locationManager.userLocation
    }

    /// 筛选后的POI列表
    private var displayedPOIs: [POI] {
        poiManager.filterByType(selectedFilter)
    }

    /// 已发现的POI数量
    private var discoveredCount: Int {
        displayedPOIs.count
    }

    /// 筛选类型列表（按功能分组排序：医疗、食物、物资、公共设施、居住）
    private let filterTypes: [POIType?] = [
        nil,            // 全部
        // 医疗类
        .hospital,
        .pharmacy,
        // 食物类
        .supermarket,
        .restaurant,
        // 物资类
        .factory,
        .warehouse,
        .gasStation,
        .hardware,
        .autoRepair,
        // 公共设施
        .school,
        .police,
        .fireStation,
        .bank,
        .gym,
        // 居住/休闲
        .residence,
        .park
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
            .navigationTitle("附近地点")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(ApocalypseTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Subviews

    /// 状态栏 - 显示GPS坐标、玩家数量和发现数量
    private var statusBar: some View {
        VStack(spacing: 8) {
            // 第一行：GPS和玩家数量
            HStack {
                // GPS坐标
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(userCoordinate != nil ? ApocalypseTheme.success : ApocalypseTheme.textMuted)

                    if let coord = userCoordinate {
                        Text(String(format: "%.4f, %.4f", coord.latitude, coord.longitude))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    } else {
                        Text("定位中...")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }

                Spacer()

                // 附近玩家数量
                if hasSearched {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.warning)

                        Text("\(poiManager.nearbyPlayersCount) 幸存者")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }

            // 第二行：统计信息
            if hasSearched {
                HStack {
                    // 发现数量
                    HStack(spacing: 6) {
                        Image(systemName: "building.2.fill")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.primary)

                        if let stats = poiManager.searchStats {
                            Text(stats.summary)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        } else {
                            Text("\(discoveredCount) 个地点")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }

                    Spacer()

                    // 区域密度
                    HStack(spacing: 4) {
                        Circle()
                            .fill(densityColor)
                            .frame(width: 8, height: 8)

                        Text(poiManager.densityDescription)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }

    /// 密度颜色
    private var densityColor: Color {
        switch poiManager.playerDensity {
        case "empty":
            return ApocalypseTheme.success
        case "low":
            return Color.green
        case "medium":
            return ApocalypseTheme.warning
        case "high":
            return ApocalypseTheme.danger
        default:
            return ApocalypseTheme.textMuted
        }
    }

    /// 搜索按钮
    private var searchButton: some View {
        VStack(spacing: 8) {
            Button {
                performSearch()
            } label: {
                HStack(spacing: 12) {
                    if poiManager.isLoading {
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
                .background(
                    (poiManager.isLoading || userCoordinate == nil)
                        ? ApocalypseTheme.textMuted
                        : ApocalypseTheme.primary
                )
                .cornerRadius(12)
            }
            .disabled(poiManager.isLoading || userCoordinate == nil)

            // 错误提示
            if let error = poiManager.lastError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.danger)
            }

            // 定位提示
            if userCoordinate == nil {
                Text("请先开启定位权限")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.warning)
            }
        }
    }

    /// 筛选工具栏
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
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }

    /// POI列表
    private var poiList: some View {
        LazyVStack(spacing: 12) {
            if displayedPOIs.isEmpty {
                // 空状态
                emptyStateView
            } else {
                ForEach(displayedPOIs) { poi in
                    NavigationLink(destination: POIDetailView(poi: poi)) {
                        POICard(poi: poi, userCoordinate: userCoordinate)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: hasSearched ? "mappin.slash" : "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(hasSearched ? "没有找到该类型的地点" : "点击上方按钮搜索附近地点")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            if !hasSearched {
                Text("搜索半径: 1公里")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Methods

    /// 执行搜索
    private func performSearch() {
        guard let coordinate = userCoordinate else {
            return
        }

        Task {
            await poiManager.refreshNearbyPOIs(around: coordinate)
            hasSearched = true
        }
    }
}

// MARK: - 筛选芯片组件

struct FilterChip: View {
    let type: POIType?
    let isSelected: Bool
    let action: () -> Void

    /// 获取显示文字
    private var displayText: String {
        guard let type = type else { return "全部" }
        return type.rawValue
    }

    /// 获取图标
    private var iconName: String {
        guard let type = type else { return "square.grid.2x2" }
        return POITypeStyle.icon(for: type)
    }

    /// 获取颜色
    private var color: Color {
        guard let type = type else { return ApocalypseTheme.primary }
        return POITypeStyle.color(for: type)
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

// MARK: - POI卡片组件

struct POICard: View {
    let poi: POI
    var userCoordinate: CLLocationCoordinate2D?

    /// 距离文本
    private var distanceText: String {
        guard let coord = userCoordinate else { return "" }
        return poi.formattedDistance(to: coord)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 左侧类型图标
            poiIcon

            // 中间信息
            VStack(alignment: .leading, spacing: 4) {
                // 名称
                Text(poi.name)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                // 类型和距离
                HStack(spacing: 8) {
                    // 类型标签
                    Text(poi.type.rawValue)
                        .font(.caption)
                        .foregroundColor(POITypeStyle.color(for: poi.type))

                    // 废墟标签（虚拟POI）
                    if poi.isVirtual {
                        Text("废墟")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ApocalypseTheme.textMuted)
                            .cornerRadius(4)
                    }

                    // 距离
                    if !distanceText.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "location.fill")
                            Text(distanceText)
                        }
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    // 危险等级
                    dangerLevelBadge
                }
            }

            Spacer()

            // 右侧箭头
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// POI类型图标
    private var poiIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(POITypeStyle.color(for: poi.type).opacity(0.2))
                .frame(width: 50, height: 50)

            Image(systemName: POITypeStyle.icon(for: poi.type))
                .font(.title2)
                .foregroundColor(POITypeStyle.color(for: poi.type))
        }
    }

    /// 危险等级徽章
    private var dangerLevelBadge: some View {
        let (text, color) = dangerInfo
        return HStack(spacing: 2) {
            Image(systemName: "exclamationmark.shield.fill")
            Text(text)
        }
        .font(.caption2)
        .foregroundColor(color)
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
}

// MARK: - POI类型样式

/// POI类型的图标和颜色配置
enum POITypeStyle {

    /// 获取类型对应的图标
    static func icon(for type: POIType) -> String {
        switch type {
        case .hospital:
            return "cross.case.fill"
        case .pharmacy:
            return "pills.fill"
        case .supermarket:
            return "cart.fill"
        case .restaurant:
            return "fork.knife"
        case .factory:
            return "building.2.fill"
        case .warehouse:
            return "shippingbox.fill"
        case .gasStation:
            return "fuelpump.fill"
        case .hardware:
            return "wrench.fill"
        case .school:
            return "book.fill"
        case .police:
            return "shield.fill"
        case .fireStation:
            return "flame.fill"
        case .bank:
            return "banknote.fill"
        case .residence:
            return "house.fill"
        case .park:
            return "leaf.fill"
        case .gym:
            return "sportscourt.fill"
        case .autoRepair:
            return "car.fill"
        }
    }

    /// 获取类型对应的颜色
    static func color(for type: POIType) -> Color {
        switch type {
        case .hospital:
            return Color.red                                // 红色
        case .pharmacy:
            return Color.purple                             // 紫色
        case .supermarket:
            return Color.green                              // 绿色
        case .restaurant:
            return Color.orange                             // 橙色
        case .factory:
            return Color.gray                               // 灰色
        case .warehouse:
            return Color.brown                              // 棕色
        case .gasStation:
            return Color.yellow                             // 黄色
        case .hardware:
            return Color(red: 0.45, green: 0.52, blue: 0.55)  // 蓝灰色
        case .school:
            return Color.blue                               // 蓝色
        case .police:
            return Color(red: 0.0, green: 0.2, blue: 0.5)   // 深蓝色
        case .fireStation:
            return Color(red: 1.0, green: 0.4, blue: 0.2)   // 红橙色
        case .bank:
            return Color(red: 0.85, green: 0.65, blue: 0.13) // 金色
        case .residence:
            return Color.cyan                               // 青色
        case .park:
            return Color(red: 0.56, green: 0.93, blue: 0.56) // 浅绿色
        case .gym:
            return Color(red: 0.78, green: 0.22, blue: 0.55) // 紫红色
        case .autoRepair:
            return Color(red: 0.38, green: 0.40, blue: 0.42) // 铁灰色
        }
    }
}

// MARK: - Preview

#Preview {
    POIListView()
}
