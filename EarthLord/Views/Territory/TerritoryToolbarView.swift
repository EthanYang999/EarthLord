//
//  TerritoryToolbarView.swift
//  EarthLord
//
//  领地详情页顶部工具栏
//  包含返回、建造、信息面板开关按钮
//

import SwiftUI

/// 领地详情页顶部工具栏
struct TerritoryToolbarView: View {

    // MARK: - Properties

    /// 关闭回调
    let onDismiss: () -> Void

    /// 打开建筑浏览器回调
    let onBuildingBrowser: () -> Void

    /// 信息面板显示状态
    @Binding var showInfoPanel: Bool

    // MARK: - Body

    var body: some View {
        HStack {
            // 返回按钮
            Button {
                onDismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("返回")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.cardBackground.opacity(0.9))
                .cornerRadius(20)
            }

            Spacer()

            // 建造按钮
            Button {
                onBuildingBrowser()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                    Text("建造")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.primary.opacity(0.9))
                .cornerRadius(20)
            }

            // 信息面板开关
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showInfoPanel.toggle()
                }
            } label: {
                Image(systemName: showInfoPanel ? "info.circle.fill" : "info.circle")
                    .font(.title2)
                    .foregroundColor(showInfoPanel ? ApocalypseTheme.primary : .white)
                    .padding(10)
                    .background(ApocalypseTheme.cardBackground.opacity(0.9))
                    .clipShape(Circle())
            }
        }
        .padding(.top, 50)
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()

        VStack {
            TerritoryToolbarView(
                onDismiss: {},
                onBuildingBrowser: {},
                showInfoPanel: .constant(true)
            )
            Spacer()
        }
    }
}
