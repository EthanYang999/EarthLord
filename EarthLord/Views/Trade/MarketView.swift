//
//  MarketView.swift
//  EarthLord
//
//  交易市场页面（占位符）
//

import SwiftUI

struct MarketView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "cart")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text("交易市场")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text("功能开发中")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ApocalypseTheme.background)
    }
}

#Preview {
    MarketView()
}
