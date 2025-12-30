//
//  MoreTabView.swift
//  EarthLord
//
//  Created by Ethan on 2025/12/24.
//

import SwiftUI
import Supabase

struct MoreTabView: View {
    @EnvironmentObject var authManager: AuthManager

    /// 是否显示退出确认弹窗
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            List {
                // 用户信息
                if let user = authManager.currentUser {
                    Section("账号信息") {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(ApocalypseTheme.primary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.email ?? "未知邮箱")
                                    .font(.headline)
                                Text("ID: \(user.id.uuidString.prefix(8))...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // 开发者工具
                Section("开发者工具") {
                    NavigationLink {
                        SupabaseTestView()
                    } label: {
                        Label("Supabase 连接测试", systemImage: "server.rack")
                    }
                }

                // 账号操作
                Section {
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("更多")
            .alert("确认退出", isPresented: $showSignOutAlert) {
                Button("取消", role: .cancel) { }
                Button("退出", role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
            } message: {
                Text("确定要退出当前账号吗？")
            }
        }
    }
}

#Preview {
    MoreTabView()
        .environmentObject(AuthManager())
}
