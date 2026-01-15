//
//  ResourceRow.swift
//  EarthLord
//
//  资源行组件（显示所需资源和拥有量）
//

import SwiftUI

/// 资源行组件
struct ResourceRow: View {
    let resourceName: String
    let required: Int
    let available: Int

    /// 是否资源充足
    private var hasEnough: Bool {
        available >= required
    }

    /// 状态颜色
    private var statusColor: Color {
        hasEnough ? ApocalypseTheme.success : ApocalypseTheme.danger
    }

    /// 资源图标
    private var resourceIcon: String {
        switch resourceName {
        case "木材": return "leaf.fill"
        case "石头": return "mountain.2.fill"
        case "废金属": return "gearshape.fill"
        case "玻璃": return "sparkles"
        default: return "cube.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 资源图标
            Image(systemName: resourceIcon)
                .font(.title3)
                .foregroundColor(statusColor)
                .frame(width: 24)

            // 资源名称
            Text(resourceName)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 数量对比
            HStack(spacing: 4) {
                Text("\(required)")
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)

                Text("/")
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("\(available)")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .font(.subheadline)

            // 状态图标
            Image(systemName: hasEnough ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(statusColor)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
        .cornerRadius(8)
    }
}

#Preview {
    VStack(spacing: 8) {
        ResourceRow(resourceName: "木材", required: 30, available: 150)
        ResourceRow(resourceName: "石头", required: 20, available: 10)
        ResourceRow(resourceName: "废金属", required: 50, available: 50)
    }
    .padding()
    .background(ApocalypseTheme.background)
}
