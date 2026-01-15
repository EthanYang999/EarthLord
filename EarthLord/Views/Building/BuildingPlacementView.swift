//
//  BuildingPlacementView.swift
//  EarthLord
//
//  建造确认页面
//  显示建筑信息、选择位置、确认建造
//

import SwiftUI
import MapKit

/// 建造确认页面
struct BuildingPlacementView: View {
    // MARK: - Properties

    /// 选择的建筑模板
    let template: BuildingTemplate

    /// 领地ID
    let territoryId: String

    /// 领地边界坐标（多边形）
    let territoryCoordinates: [CLLocationCoordinate2D]

    /// 关闭回调
    let onDismiss: () -> Void

    /// 建造完成回调
    let onConstructionStarted: (PlayerBuilding) -> Void

    // MARK: - State

    /// 选中的建造位置
    @State private var selectedLocation: CLLocationCoordinate2D?

    /// 是否显示位置选择器
    @State private var showLocationPicker = false

    /// 是否正在建造
    @State private var isConstructing = false

    /// 错误消息
    @State private var errorMessage: String?

    /// 是否显示错误
    @State private var showError = false

    // MARK: - Managers

    @ObservedObject private var inventoryManager = InventoryManager.shared
    @ObservedObject private var buildingManager = BuildingManager.shared

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

    /// 是否可以开始建造
    private var canStartConstruction: Bool {
        hasEnoughResources && selectedLocation != nil && !isConstructing
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 建筑预览
                        buildingPreview

                        // 位置选择
                        locationSection

                        // 资源消耗
                        resourceSection

                        // 建造时间
                        buildTimeSection

                        // 建造按钮
                        constructButton
                    }
                    .padding()
                }
            }
            .navigationTitle("确认建造")
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
        .sheet(isPresented: $showLocationPicker) {
            BuildingLocationPickerView(
                territoryCoordinates: territoryCoordinates,
                existingBuildings: buildingManager.playerBuildings.filter { $0.territoryId == territoryId },
                buildingTemplates: buildingManager.buildingTemplates,
                onSelectLocation: { coord in
                    selectedLocation = coord
                    showLocationPicker = false
                },
                onCancel: {
                    showLocationPicker = false
                }
            )
        }
        .alert("建造失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    // MARK: - Subviews

    /// 建筑预览
    private var buildingPreview: some View {
        VStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(template.category.color.opacity(0.2))
                    .frame(width: 70, height: 70)

                Image(systemName: template.icon)
                    .font(.system(size: 35))
                    .foregroundColor(template.category.color)
            }

            // 名称
            Text(template.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 分类
            Label(template.category.displayName, systemImage: template.category.icon)
                .font(.subheadline)
                .foregroundColor(template.category.color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 位置选择区域
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("建造位置", systemImage: "mappin.and.ellipse")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Button {
                showLocationPicker = true
            } label: {
                HStack {
                    if let location = selectedLocation {
                        // 已选择位置
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(ApocalypseTheme.success)
                                Text("已选择位置")
                                    .fontWeight(.medium)
                                    .foregroundColor(ApocalypseTheme.textPrimary)
                            }

                            Text(String(format: "%.5f, %.5f", location.latitude, location.longitude))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    } else {
                        // 未选择
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundColor(ApocalypseTheme.primary)
                            Text("点击选择建造位置")
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .padding()
                .background(ApocalypseTheme.cardBackground.opacity(0.5))
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 资源消耗区域
    private var resourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("资源消耗", systemImage: "cube.box")
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
        HStack {
            Label("建造时间", systemImage: "clock")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            Text(template.formattedBuildTime)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.primary)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 建造按钮
    private var constructButton: some View {
        Button {
            Task {
                await startConstruction()
            }
        } label: {
            HStack {
                if isConstructing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "hammer.fill")
                }
                Text(isConstructing ? "建造中..." : "确认建造")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(canStartConstruction ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            .cornerRadius(12)
        }
        .disabled(!canStartConstruction)
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

    /// 开始建造
    private func startConstruction() async {
        guard let location = selectedLocation else {
            errorMessage = "请先选择建造位置"
            showError = true
            return
        }

        isConstructing = true

        do {
            let request = BuildingConstructionRequest(
                templateId: template.templateId,
                territoryId: territoryId,
                location: location,
                customName: nil
            )

            let building = try await buildingManager.startConstruction(request: request)

            await MainActor.run {
                isConstructing = false
                onConstructionStarted(building)
            }
        } catch let error as BuildingError {
            await MainActor.run {
                isConstructing = false
                errorMessage = error.localizedDescription
                showError = true
            }
        } catch {
            await MainActor.run {
                isConstructing = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    BuildingPlacementView(
        template: BuildingTemplate(
            id: "campfire",
            templateId: "campfire",
            name: "篝火",
            tier: 1,
            category: .survival,
            description: "简单的篝火，提供照明和取暖。",
            icon: "flame.fill",
            requiredResources: ["木材": 30, "石头": 20],
            buildTimeSeconds: 60,
            maxPerTerritory: 3,
            maxLevel: 5
        ),
        territoryId: "test-territory",
        territoryCoordinates: [
            CLLocationCoordinate2D(latitude: 31.230, longitude: 121.470),
            CLLocationCoordinate2D(latitude: 31.230, longitude: 121.475),
            CLLocationCoordinate2D(latitude: 31.235, longitude: 121.475),
            CLLocationCoordinate2D(latitude: 31.235, longitude: 121.470)
        ],
        onDismiss: {},
        onConstructionStarted: { _ in }
    )
}
