//
//  BuildingBrowserView.swift
//  EarthLord
//
//  建筑浏览页
//  显示所有可建造的建筑模板，支持分类筛选
//

import SwiftUI

/// 建筑浏览页
struct BuildingBrowserView: View {
    // MARK: - Properties

    @ObservedObject var buildingManager = BuildingManager.shared

    /// 关闭回调
    let onDismiss: () -> Void

    /// 开始建造回调（返回选中的模板）
    let onStartConstruction: (BuildingTemplate) -> Void

    // MARK: - State

    /// 选中的分类（nil = 全部）
    @State private var selectedCategory: BuildingCategory? = nil

    /// 选中的建筑（用于显示详情页）
    @State private var selectedBuilding: BuildingTemplate? = nil

    // MARK: - Computed Properties

    /// 筛选后的模板列表
    private var filteredTemplates: [BuildingTemplate] {
        if let category = selectedCategory {
            return buildingManager.getTemplates(byCategory: category)
        } else {
            return buildingManager.getAllTemplates()
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 分类选择器
                    categorySelector
                        .padding(.horizontal)
                        .padding(.vertical, 12)

                    // 建筑网格
                    buildingGrid
                }
            }
            .navigationTitle("选择建筑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onDismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }
        }
        // 建筑详情 Sheet（由 Browser 内部管理）
        .sheet(item: $selectedBuilding) { template in
            BuildingDetailView(
                template: template,
                onDismiss: {
                    selectedBuilding = nil
                },
                onStartConstruction: {
                    selectedBuilding = nil  // 先关闭详情页
                    onStartConstruction(template)  // 触发父级回调
                }
            )
        }
        .onAppear {
            buildingManager.loadTemplates()
        }
    }

    // MARK: - Subviews

    /// 分类选择器
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 全部
                CategoryButton(
                    category: nil,
                    isSelected: selectedCategory == nil,
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = nil
                        }
                    }
                )

                // 各分类
                ForEach(BuildingCategory.allCases, id: \.self) { category in
                    CategoryButton(
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

    /// 建筑网格
    private var buildingGrid: some View {
        ScrollView {
            if filteredTemplates.isEmpty {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: "building.2")
                        .font(.system(size: 60))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text("暂无建筑模板")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(filteredTemplates) { template in
                        BuildingCard(template: template) {
                            selectedBuilding = template
                        }
                    }
                }
                .padding()
            }
        }
    }
}

#Preview {
    BuildingBrowserView(
        onDismiss: {},
        onStartConstruction: { _ in }
    )
}
