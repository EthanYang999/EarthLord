//
//  RootView.swift
//  EarthLord
//
//  Created by Ethan on 2025/12/24.
//

import SwiftUI

/// 根视图：控制启动页、认证页与主界面的切换
///
/// 页面流转逻辑：
/// 1. 启动页（SplashView）：显示 Logo 和加载动画，同时检查认证状态
/// 2. 认证页（AuthView）：未登录时显示，包含登录/注册/找回密码
/// 3. 主界面（MainTabView）：已登录后显示
struct RootView: View {
    /// 启动页是否完成
    @State private var splashFinished = false

    /// 认证管理器（全局共享）
    @StateObject private var authManager = AuthManager()

    var body: some View {
        ZStack {
            if !splashFinished {
                // 启动页：检查登录状态
                SplashView(isFinished: $splashFinished)
                    .environmentObject(authManager)
                    .transition(.opacity)
            } else if !authManager.isAuthenticated {
                // 未登录：显示认证页面
                AuthView()
                    .environmentObject(authManager)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                // 已登录：显示主界面
                MainTabView()
                    .environmentObject(authManager)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: splashFinished)
        .animation(.easeInOut(duration: 0.4), value: authManager.isAuthenticated)
    }
}

#Preview {
    RootView()
}
