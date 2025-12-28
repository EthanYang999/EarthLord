//
//  MoreTabView.swift
//  EarthLord
//
//  Created by Ethan on 2025/12/24.
//

import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("开发者工具") {
                    NavigationLink {
                        SupabaseTestView()
                    } label: {
                        Label("Supabase 连接测试", systemImage: "server.rack")
                    }
                }
            }
            .navigationTitle("更多")
        }
    }
}

#Preview {
    MoreTabView()
}
