//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情页 - 全屏地图布局
//  显示领地多边形、建筑标记、悬浮工具栏、可折叠信息面板
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - Properties

    /// 领地数据
    @State var territory: Territory

    /// 删除回调
    var onDelete: (() -> Void)?

    /// 关闭 sheet 的环境变量
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    /// 是否显示信息面板
    @State private var showInfoPanel = true

    /// 是否显示删除确认弹窗
    @State private var showDeleteAlert = false

    /// 是否正在删除
    @State private var isDeleting = false

    /// 是否显示建筑浏览器
    @State private var showBuildingBrowser = false

    /// 选中的建筑模板（用于建造确认）
    @State private var selectedTemplateForConstruction: BuildingTemplate?

    /// 选中的建筑（用于升级/拆除）
    @State private var selectedBuilding: PlayerBuilding?

    /// 是否显示升级确认
    @State private var showUpgradeConfirm = false

    /// 是否显示拆除确认
    @State private var showDemolishConfirm = false

    /// 是否显示重命名对话框
    @State private var showRenameDialog = false

    /// 新领地名称
    @State private var newTerritoryName = ""

    /// 领地管理器
    private let territoryManager = TerritoryManager.shared

    /// 建筑管理器
    @ObservedObject private var buildingManager = BuildingManager.shared

    // MARK: - Computed Properties

    /// 领地坐标（转换为 GCJ-02）
    private var territoryCoordinates: [CLLocationCoordinate2D] {
        let wgs84Coords = territory.toCoordinates()
        return CoordinateConverter.wgs84ToGcj02Array(wgs84Coords)
    }

    /// 格式化完成时间
    private var formattedCompletedAt: String {
        guard let completedAt = territory.completedAt else { return "未知" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: completedAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            return displayFormatter.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: completedAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            return displayFormatter.string(from: date)
        }
        return completedAt
    }

    /// 该领地的建筑列表
    private var territoryBuildings: [PlayerBuilding] {
        buildingManager.playerBuildings.filter { $0.territoryId == territory.id }
    }

    /// 建筑模板字典
    private var templateDict: [String: BuildingTemplate] {
        buildingManager.buildingTemplates
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 1. 全屏地图（底层）
            TerritoryMapView(
                territoryCoordinates: territoryCoordinates,
                buildings: territoryBuildings,
                templates: templateDict
            )
            .ignoresSafeArea()

            // 2. 悬浮工具栏（顶部）
            VStack {
                TerritoryToolbarView(
                    onDismiss: {
                        dismiss()
                    },
                    onBuildingBrowser: {
                        showBuildingBrowser = true
                    },
                    showInfoPanel: $showInfoPanel
                )

                Spacer()
            }

            // 3. 可折叠信息面板（底部）
            VStack {
                Spacer()

                if showInfoPanel {
                    infoPanelView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        // 领地删除确认
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                Task {
                    await deleteTerritory()
                }
            }
        } message: {
            Text("确定要删除这块领地吗？此操作不可撤销。")
        }
        // 建筑升级确认
        .alert("升级建筑", isPresented: $showUpgradeConfirm) {
            Button("取消", role: .cancel) { }
            Button("升级") {
                Task {
                    await upgradeBuilding()
                }
            }
        } message: {
            if let building = selectedBuilding {
                Text("确定要将「\(building.buildingName)」升级到 Lv.\(building.level + 1) 吗？")
            }
        }
        // 建筑拆除确认
        .alert("拆除建筑", isPresented: $showDemolishConfirm) {
            Button("取消", role: .cancel) { }
            Button("拆除", role: .destructive) {
                Task {
                    await demolishBuilding()
                }
            }
        } message: {
            if let building = selectedBuilding {
                Text("确定要拆除「\(building.buildingName)」吗？此操作不可撤销。")
            }
        }
        // 领地重命名对话框
        .alert("重命名领地", isPresented: $showRenameDialog) {
            TextField("输入新名称", text: $newTerritoryName)
            Button("取消", role: .cancel) { }
            Button("确定") {
                Task {
                    await renameTerritory()
                }
            }
            .disabled(newTerritoryName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("请输入领地的新名称")
        }
        // 建筑浏览器 Sheet
        .sheet(isPresented: $showBuildingBrowser) {
            BuildingBrowserView(
                onDismiss: {
                    showBuildingBrowser = false
                },
                onStartConstruction: { template in
                    showBuildingBrowser = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedTemplateForConstruction = template
                    }
                }
            )
        }
        // 建造确认 Sheet
        .sheet(item: $selectedTemplateForConstruction) { template in
            BuildingPlacementView(
                template: template,
                territoryId: territory.id,
                territoryCoordinates: territoryCoordinates,
                onDismiss: {
                    selectedTemplateForConstruction = nil
                },
                onConstructionStarted: { building in
                    selectedTemplateForConstruction = nil
                    Task {
                        await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
                    }
                }
            )
        }
        .onAppear {
            buildingManager.loadTemplates()
            Task {
                await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
            }
        }
    }

    // MARK: - Info Panel

    /// 底部信息面板
    private var infoPanelView: some View {
        VStack(spacing: 0) {
            // 拖拽指示器
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 16) {
                    // 领地名称 + 重命名按钮
                    HStack {
                        Text(territory.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Spacer()

                        // 重命名按钮
                        Button {
                            newTerritoryName = territory.name ?? ""
                            showRenameDialog = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundColor(ApocalypseTheme.primary)
                        }
                    }

                    // 领地信息卡片
                    infoCard

                    // 建筑区域
                    buildingSection

                    // 删除按钮
                    deleteButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.55)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ApocalypseTheme.cardBackground.opacity(0.95))
                .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
        )
    }

    /// 领地信息卡片
    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow(icon: "square.dashed", label: "面积", value: territory.formattedArea)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            infoRow(
                icon: "mappin.and.ellipse",
                label: "边界点数",
                value: "\(territory.pointCount ?? 0) 个"
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            infoRow(icon: "clock", label: "圈地时间", value: formattedCompletedAt)
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 信息行
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)

            Text(label)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .fontWeight(.medium)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
    }

    /// 建筑区域
    private var buildingSection: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Label("建筑", systemImage: "building.2")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 建筑数量
                Text("\(territoryBuildings.count)")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 建筑列表
            if territoryBuildings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "hammer")
                        .font(.system(size: 40))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text("暂无建筑")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("点击顶部「建造」按钮开始")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(ApocalypseTheme.cardBackground)
            } else {
                VStack(spacing: 0) {
                    ForEach(territoryBuildings) { building in
                        if let template = buildingManager.getTemplate(by: building.templateId) {
                            VStack(spacing: 0) {
                                TerritoryBuildingRow(
                                    building: building,
                                    template: template,
                                    onUpgrade: {
                                        selectedBuilding = building
                                        showUpgradeConfirm = true
                                    },
                                    onDemolish: {
                                        selectedBuilding = building
                                        showDemolishConfirm = true
                                    }
                                )
                                .padding(.horizontal)
                                .padding(.vertical, 8)

                                if building.id != territoryBuildings.last?.id {
                                    Divider()
                                        .background(ApocalypseTheme.textMuted.opacity(0.3))
                                }
                            }
                        }
                    }
                }
                .background(ApocalypseTheme.cardBackground)
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 删除按钮
    private var deleteButton: some View {
        Button {
            showDeleteAlert = true
        } label: {
            HStack {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "trash")
                }
                Text(isDeleting ? "删除中..." : "删除领地")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(ApocalypseTheme.danger)
            .cornerRadius(12)
        }
        .disabled(isDeleting)
    }

    // MARK: - Methods

    /// 删除领地
    private func deleteTerritory() async {
        isDeleting = true

        let success = await territoryManager.deleteTerritory(territoryId: territory.id)

        await MainActor.run {
            isDeleting = false
            if success {
                onDelete?()
                dismiss()
            }
        }
    }

    /// 升级建筑
    private func upgradeBuilding() async {
        guard let building = selectedBuilding else { return }

        do {
            _ = try await buildingManager.upgradeBuilding(buildingId: building.id)
            await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
        } catch {
            print("[TerritoryDetailView] 升级失败: \(error.localizedDescription)")
        }
    }

    /// 拆除建筑
    private func demolishBuilding() async {
        guard let building = selectedBuilding else { return }

        do {
            try await buildingManager.demolishBuilding(buildingId: building.id)
            await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
        } catch {
            print("[TerritoryDetailView] 拆除失败: \(error.localizedDescription)")
        }
    }

    /// 重命名领地
    private func renameTerritory() async {
        let trimmedName = newTerritoryName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let success = await territoryManager.updateTerritoryName(
            territoryId: territory.id,
            newName: trimmedName
        )

        if success {
            await MainActor.run {
                // 更新本地显示的名称
                territory = Territory(
                    id: territory.id,
                    userId: territory.userId,
                    name: trimmedName,
                    path: territory.path,
                    area: territory.area,
                    pointCount: territory.pointCount,
                    isActive: territory.isActive,
                    completedAt: territory.completedAt,
                    startedAt: territory.startedAt,
                    createdAt: territory.createdAt
                )

                // 发送通知刷新领地列表
                NotificationCenter.default.post(name: .territoryUpdated, object: nil)
            }
        }
    }
}

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "preview-id",
            userId: "user-id",
            name: "测试领地",
            path: [
                ["lat": 31.2, "lon": 121.4],
                ["lat": 31.2, "lon": 121.5],
                ["lat": 31.3, "lon": 121.5],
                ["lat": 31.3, "lon": 121.4]
            ],
            area: 12345,
            pointCount: 4,
            isActive: true,
            completedAt: "2025-01-06T12:00:00Z",
            startedAt: "2025-01-06T11:55:00Z",
            createdAt: "2025-01-06T12:00:00Z"
        ),
        onDelete: nil
    )
}
