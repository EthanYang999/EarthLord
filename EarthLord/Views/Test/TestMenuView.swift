//
//  TestMenuView.swift
//  EarthLord
//
//  测试模块入口菜单 - 开发者工具列表
//

import SwiftUI

/// 测试模块入口菜单
/// ⚠️ 注意：此视图不需要套 NavigationStack，因为它在 MoreTabView 的 NavigationStack 内部
struct TestMenuView: View {

    var body: some View {
        List {
            // Supabase 连接测试
            NavigationLink {
                SupabaseTestView()
            } label: {
                Label {
                    Text("Supabase 连接测试")
                } icon: {
                    Image(systemName: "server.rack")
                        .foregroundColor(ApocalypseTheme.info)
                }
            }

            // 圈地功能测试
            NavigationLink {
                TerritoryTestView()
            } label: {
                Label {
                    Text("圈地功能测试")
                } icon: {
                    Image(systemName: "flag.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .navigationTitle("开发测试")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        TestMenuView()
    }
}
