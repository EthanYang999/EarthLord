//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情页 - 显示领地信息、地图预览、删除功能
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - Properties

    /// 领地数据
    let territory: Territory

    /// 删除回调
    var onDelete: (() -> Void)?

    /// 关闭 sheet 的环境变量
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    /// 是否显示删除确认弹窗
    @State private var showDeleteAlert = false

    /// 是否正在删除
    @State private var isDeleting = false

    /// 地图相机位置
    @State private var cameraPosition: MapCameraPosition = .automatic

    /// 领地管理器
    private let territoryManager = TerritoryManager.shared

    // MARK: - Computed Properties

    /// 领地坐标（转换为 GCJ-02）
    private var territoryCoordinates: [CLLocationCoordinate2D] {
        let wgs84Coords = territory.toCoordinates()
        return CoordinateConverter.wgs84ToGcj02Array(wgs84Coords)
    }

    /// 领地中心点
    private var centerCoordinate: CLLocationCoordinate2D? {
        guard !territoryCoordinates.isEmpty else { return nil }
        let latSum = territoryCoordinates.reduce(0) { $0 + $1.latitude }
        let lonSum = territoryCoordinates.reduce(0) { $0 + $1.longitude }
        return CLLocationCoordinate2D(
            latitude: latSum / Double(territoryCoordinates.count),
            longitude: lonSum / Double(territoryCoordinates.count)
        )
    }

    /// 格式化完成时间
    private var formattedCompletedAt: String {
        guard let completedAt = territory.completedAt else { return "未知" }
        // ISO8601 格式解析
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: completedAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            return displayFormatter.string(from: date)
        }
        // 尝试不带毫秒的格式
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: completedAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            return displayFormatter.string(from: date)
        }
        return completedAt
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 地图预览
                        mapPreview

                        // 领地信息
                        infoSection

                        // 未来功能占位
                        futureFeatures

                        // 删除按钮
                        deleteButton
                    }
                    .padding()
                }
            }
            .navigationTitle(territory.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ApocalypseTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
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
        }
    }

    // MARK: - Subviews

    /// 地图预览
    private var mapPreview: some View {
        ZStack {
            if let center = centerCoordinate {
                Map(position: $cameraPosition) {
                    // 领地多边形
                    MapPolygon(coordinates: territoryCoordinates)
                        .foregroundStyle(Color.green.opacity(0.3))
                        .stroke(Color.green, lineWidth: 2)
                }
                .mapStyle(.hybrid)
                .frame(height: 200)
                .cornerRadius(12)
                .onAppear {
                    // 设置地图区域
                    cameraPosition = .region(MKCoordinateRegion(
                        center: center,
                        latitudinalMeters: 500,
                        longitudinalMeters: 500
                    ))
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
                    .frame(height: 200)
                    .overlay {
                        Text("无法显示地图")
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
            }
        }
    }

    /// 领地信息区域
    private var infoSection: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("领地信息")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 面积
            infoRow(icon: "square.dashed", label: "面积", value: territory.formattedArea)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 边界点数
            infoRow(
                icon: "mappin.and.ellipse",
                label: "边界点数",
                value: "\(territory.pointCount ?? 0) 个"
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 完成时间
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

    /// 未来功能占位区
    private var futureFeatures: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("更多功能")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 重命名
            futureFeatureRow(icon: "pencil", label: "重命名领地")

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 建筑系统
            futureFeatureRow(icon: "building.2", label: "建筑系统")

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 领地交易
            futureFeatureRow(icon: "arrow.left.arrow.right", label: "领地交易")
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 未来功能行
    private func futureFeatureRow(icon: String, label: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 24)

            Text(label)
                .foregroundColor(ApocalypseTheme.textMuted)

            Spacer()

            Text("敬请期待")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.textMuted.opacity(0.2))
                .cornerRadius(4)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
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
        .padding(.top, 10)
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
