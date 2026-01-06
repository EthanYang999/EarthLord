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
    @ObservedObject var languageManager = LanguageManager.shared

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

                // 设置
                Section("设置") {
                    NavigationLink {
                        LanguageSettingsView()
                    } label: {
                        HStack {
                            Label("语言", systemImage: "globe")
                            Spacer()
                            Text(languageManager.selectedLanguage.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 开发者工具
                Section("开发者工具") {
                    NavigationLink {
                        TestMenuView()
                    } label: {
                        Label("开发测试", systemImage: "hammer.fill")
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
