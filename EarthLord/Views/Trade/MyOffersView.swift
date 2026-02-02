//
//  MyOffersView.swift
//  EarthLord
//
//  我的挂单页面（占位符）
//

import SwiftUI

struct MyOffersView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text("我的挂单")
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
    MyOffersView()
}
