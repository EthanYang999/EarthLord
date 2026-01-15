//
//  ProfileTabView.swift
//  EarthLord
//
//  Created by Ethan on 2025/12/24.
//

import SwiftUI
import Supabase

struct ProfileTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var languageManager = LanguageManager.shared

    /// 是否显示退出确认弹窗
    @State private var showSignOutAlert = false

    /// 是否显示删除账户确认弹窗
    @State private var showDeleteAccountAlert = false

    /// 删除确认输入框内容
    @State private var deleteConfirmText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 用户头像和信息
                    profileHeader

                    // 统计数据
                    statsSection

                    // 功能列表
                    settingsSection

                    // 功能列表
                    menuSection

                    // 退出登录按钮
                    signOutButton

                    // 删除账户按钮
                    deleteAccountButton
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("幸存者档案")
            .navigationBarTitleDisplayMode(.inline)
        }
        // 退出登录确认
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
        // 删除账户确认
        .alert("删除账户", isPresented: $showDeleteAccountAlert) {
            TextField("请输入 DELETE", text: $deleteConfirmText)
            Button("取消", role: .cancel) {
                deleteConfirmText = ""
            }
            Button("永久删除", role: .destructive) {
                if deleteConfirmText == "DELETE" {
                    Task {
                        await authManager.deleteAccount()
                    }
                }
                deleteConfirmText = ""
            }
            .disabled(deleteConfirmText != "DELETE")
        } message: {
            Text("此操作不可逆！您的所有数据将被永久删除。\n\n请输入 DELETE 确认删除。")
        }
    }

    // MARK: - 用户头像和信息
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // 头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "person.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 10)

            // 用户名/邮箱
            VStack(spacing: 4) {
                if let user = authManager.currentUser {
                    Text(user.email?.components(separatedBy: "@").first ?? "幸存者")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(user.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("ID: \(user.id.uuidString.prefix(8))...")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                } else {
                    Text("幸存者")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - 统计数据
    private var statsSection: some View {
        HStack(spacing: 0) {
            statItem(value: "0", label: "领地", icon: "flag.fill")
            Divider()
                .frame(height: 40)
                .background(ApocalypseTheme.textMuted)
            statItem(value: "0", label: "资源点", icon: "mappin.circle.fill")
            Divider()
                .frame(height: 40)
                .background(ApocalypseTheme.textMuted)
            statItem(value: "0", label: "探索距离", icon: "figure.walk")
        }
        .padding(.vertical, 16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    private func statItem(value: String, label: LocalizedStringKey, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(ApocalypseTheme.primary)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(label)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 功能列表
    private var menuSection: some View {
        VStack(spacing: 0) {
            menuItem(icon: "bell.fill", title: "通知", color: .orange)
            Divider().background(ApocalypseTheme.textMuted.opacity(0.3))
            menuItem(icon: "questionmark.circle.fill", title: "帮助", color: .blue)
            Divider().background(ApocalypseTheme.textMuted.opacity(0.3))
            menuItem(icon: "info.circle.fill", title: "关于", color: .green)
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 设置
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设置")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            VStack(spacing: 0) {
                NavigationLink {
                    LanguageSettingsView()
                } label: {
                    HStack {
                        Image(systemName: "globe")
                            .font(.title3)
                            .foregroundColor(.orange)
                            .frame(width: 30)

                        Text("语言")
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Spacer()

                        Text(languageManager.selectedLanguage.displayName)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .padding()
                }

                Divider().background(ApocalypseTheme.textMuted.opacity(0.3))

                Link(destination: URL(string: "https://ethanyang999.github.io/earthlord-support/support/")!) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .font(.title3)
                            .foregroundColor(.orange)
                            .frame(width: 30)

                        Text("技术支持")
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .padding()
                }

                Divider().background(ApocalypseTheme.textMuted.opacity(0.3))

                Link(destination: URL(string: "https://ethanyang999.github.io/earthlord-support/privacy/")!) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                            .frame(width: 30)

                        Text("隐私政策")
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .padding()
                }
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    private func menuItem(icon: String, title: LocalizedStringKey, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)

            Text(title)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding()
        .contentShape(Rectangle())
    }

    // MARK: - 退出登录按钮
    private var signOutButton: some View {
        Button {
            showSignOutAlert = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("退出登录")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ApocalypseTheme.danger)
            .cornerRadius(12)
        }
        .padding(.top, 20)
    }

    // MARK: - 删除账户按钮
    private var deleteAccountButton: some View {
        Button {
            showDeleteAccountAlert = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                Text("删除账户")
            }
            .font(.subheadline)
            .foregroundColor(ApocalypseTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

#Preview {
    ProfileTabView()
        .environmentObject(AuthManager())
}
