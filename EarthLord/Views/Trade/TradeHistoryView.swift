//
//  TradeHistoryView.swift
//  EarthLord
//
//  交易历史页面（占位符）
//

import SwiftUI

struct TradeHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text("交易历史")
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
    TradeHistoryView()
}
