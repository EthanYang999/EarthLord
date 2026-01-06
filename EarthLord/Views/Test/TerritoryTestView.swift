//
//  TerritoryTestView.swift
//  EarthLord
//
//  圈地功能测试界面 - 显示圈地模块的调试日志
//

import SwiftUI

/// 圈地功能测试界面
/// ⚠️ 注意：此视图不需要套 NavigationStack，因为它从 TestMenuView 导航进来
struct TerritoryTestView: View {

    // MARK: - Properties

    /// 定位管理器（通过环境对象注入）
    @EnvironmentObject var locationManager: LocationManager

    /// 日志管理器（单例）
    @ObservedObject var logger = TerritoryLogger.shared

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 状态指示器
            statusIndicator
                .padding()
                .background(ApocalypseTheme.cardBackground)

            Divider()

            // 日志滚动区域
            logScrollView

            Divider()

            // 底部按钮栏
            buttonBar
                .padding()
                .background(ApocalypseTheme.cardBackground)
        }
        .background(ApocalypseTheme.background)
        .navigationTitle("圈地测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    /// 状态指示器
    private var statusIndicator: some View {
        HStack(spacing: 8) {
            // 状态圆点
            Circle()
                .fill(locationManager.isTracking ? Color.green : Color.gray)
                .frame(width: 12, height: 12)

            // 状态文字
            Text(locationManager.isTracking ? "追踪中" : "未追踪")
                .font(.headline)
                .foregroundColor(locationManager.isTracking ? ApocalypseTheme.success : ApocalypseTheme.textSecondary)

            Spacer()

            // 路径点数（追踪时显示）
            if locationManager.isTracking {
                Text("\(locationManager.pathPointCount) 个点")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }

    /// 日志滚动区域
    private var logScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(logger.logText.isEmpty ? "暂无日志，开始圈地追踪后将在此显示..." : logger.logText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(logger.logText.isEmpty ? ApocalypseTheme.textMuted : ApocalypseTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .id("logBottom")  // 用于自动滚动
            }
            .background(ApocalypseTheme.background)
            // 日志更新时自动滚动到底部
            .onChange(of: logger.logText) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("logBottom", anchor: .bottom)
                }
            }
        }
    }

    /// 底部按钮栏
    private var buttonBar: some View {
        HStack(spacing: 16) {
            // 清空日志按钮
            Button {
                logger.clear()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("清空日志")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.danger)
                .cornerRadius(10)
            }

            // 导出日志按钮
            ShareLink(item: logger.export()) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出日志")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.primary)
                .cornerRadius(10)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TerritoryTestView()
            .environmentObject(LocationManager())
    }
}
