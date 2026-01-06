//
//  TerritoryTabView.swift
//  EarthLord
//
//  领地管理页面 - 显示我的领地列表和统计信息
//

import SwiftUI

struct TerritoryTabView: View {

    // MARK: - State

    /// 我的领地列表
    @State private var myTerritories: [Territory] = []

    /// 是否正在加载
    @State private var isLoading = false

    /// 错误消息
    @State private var errorMessage: String?

    /// 选中的领地（用于显示详情）
    @State private var selectedTerritory: Territory?

    /// 领地管理器
    private let territoryManager = TerritoryManager.shared

    // MARK: - Computed Properties

    /// 总面积
    private var totalArea: Double {
        myTerritories.reduce(0) { $0 + $1.area }
    }

    /// 格式化总面积
    private var formattedTotalArea: String {
        if totalArea >= 1_000_000 {
            return String(format: "%.2f km²", totalArea / 1_000_000)
        } else {
            return String(format: "%.0f m²", totalArea)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if isLoading && myTerritories.isEmpty {
                    // 首次加载中
                    loadingView
                } else if myTerritories.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 领地列表
                    territoryListView
                }
            }
            .navigationTitle("我的领地")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(ApocalypseTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            Task {
                await loadMyTerritories()
            }
        }
        .sheet(item: $selectedTerritory) { territory in
            TerritoryDetailView(
                territory: territory,
                onDelete: {
                    // 删除后刷新列表
                    Task {
                        await loadMyTerritories()
                    }
                }
            )
        }
    }

    // MARK: - Subviews

    /// 加载中视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.5)

            Text("加载中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.slash")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("暂无领地")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("前往地图页面开始圈地，\n占领属于你的领土！")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await loadMyTerritories()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("刷新")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.primary)
                .cornerRadius(10)
            }
        }
        .padding()
    }

    /// 领地列表视图
    private var territoryListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 统计卡片
                statsCard

                // 领地卡片列表
                ForEach(myTerritories) { territory in
                    TerritoryCard(territory: territory)
                        .onTapGesture {
                            selectedTerritory = territory
                        }
                }
            }
            .padding()
        }
        .refreshable {
            await loadMyTerritories()
        }
    }

    /// 统计卡片
    private var statsCard: some View {
        HStack(spacing: 0) {
            // 领地数量
            statItem(
                icon: "flag.fill",
                value: "\(myTerritories.count)",
                label: "领地数量"
            )

            Divider()
                .frame(height: 40)
                .background(ApocalypseTheme.textMuted)

            // 总面积
            statItem(
                icon: "square.dashed",
                value: formattedTotalArea,
                label: "总面积"
            )
        }
        .padding(.vertical, 16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 统计项
    private func statItem(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(ApocalypseTheme.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(label)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Methods

    /// 加载我的领地
    private func loadMyTerritories() async {
        isLoading = true
        errorMessage = nil

        do {
            let territories = try await territoryManager.loadMyTerritories()
            await MainActor.run {
                self.myTerritories = territories
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }
}

// MARK: - 领地卡片组件

struct TerritoryCard: View {
    let territory: Territory

    var body: some View {
        HStack(spacing: 12) {
            // 左侧图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "flag.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 中间信息
            VStack(alignment: .leading, spacing: 4) {
                Text(territory.displayName)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // 面积
                    Label(territory.formattedArea, systemImage: "square.dashed")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 点数
                    if let pointCount = territory.pointCount {
                        Label("\(pointCount) 点", systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
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
}

#Preview {
    TerritoryTabView()
}
