//
//  CategoryButton.swift
//  EarthLord
//
//  建筑分类按钮组件
//

import SwiftUI

/// 分类按钮组件
struct CategoryButton: View {
    let category: BuildingCategory?
    let isSelected: Bool
    let action: () -> Void

    /// 显示文本
    private var title: String {
        category?.displayName ?? "全部"
    }

    /// 按钮颜色
    private var buttonColor: Color {
        if isSelected {
            return category?.color ?? ApocalypseTheme.primary
        } else {
            return ApocalypseTheme.cardBackground
        }
    }

    /// 文字颜色
    private var textColor: Color {
        if isSelected {
            return .white
        } else {
            return ApocalypseTheme.textSecondary
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let category = category {
                    Image(systemName: category.icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(buttonColor)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack {
        CategoryButton(category: nil, isSelected: true, action: {})
        CategoryButton(category: .survival, isSelected: false, action: {})
        CategoryButton(category: .storage, isSelected: false, action: {})
    }
    .padding()
    .background(ApocalypseTheme.background)
}
