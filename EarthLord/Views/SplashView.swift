//
//  SplashView.swift
//  EarthLord
//
//  Created by Ethan on 2025/12/24.
//

import SwiftUI

/// 启动页视图
struct SplashView: View {
    /// 认证管理器
    @EnvironmentObject var authManager: AuthManager

    /// 是否显示加载动画
    @State private var isAnimating = false

    /// 加载进度文字
    @State private var loadingText = "正在初始化..."

    /// Logo 缩放动画
    @State private var logoScale: CGFloat = 0.8

    /// Logo 透明度
    @State private var logoOpacity: Double = 0

    /// 最小显示时间是否已过
    @State private var minimumTimeElapsed = false

    /// 是否完成加载
    @Binding var isFinished: Bool

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.18),
                    Color(red: 0.09, green: 0.13, blue: 0.24),
                    Color(red: 0.06, green: 0.06, blue: 0.10)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Logo
                ZStack {
                    // 外圈光晕（呼吸动画）
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    ApocalypseTheme.primary.opacity(0.3),
                                    ApocalypseTheme.primary.opacity(0)
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: isAnimating
                        )

                    // Logo 圆形背景
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ApocalypseTheme.primary,
                                    ApocalypseTheme.primary.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 20)

                    // 地球图标
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // 标题
                VStack(spacing: 8) {
                    Text("地球新主")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("EARTH LORD")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .tracking(4)
                }
                .opacity(logoOpacity)

                Spacer()

                // 加载指示器
                VStack(spacing: 16) {
                    // 三点加载动画
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(ApocalypseTheme.primary)
                                .frame(width: 10, height: 10)
                                .scaleEffect(isAnimating ? 1.0 : 0.5)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                    value: isAnimating
                                )
                        }
                    }

                    // 加载文字
                    Text(loadingText)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startAnimations()
            startLoading()
        }
        // 监听认证初始化状态
        .onChange(of: authManager.isInitialized) { _, initialized in
            if initialized {
                loadingText = "准备就绪"
                checkAndFinish()
            }
        }
    }

    // MARK: - 动画方法

    private func startAnimations() {
        // Logo 入场动画
        withAnimation(.easeOut(duration: 0.8)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // 启动循环动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = true
        }
    }

    // MARK: - 加载流程

    private func startLoading() {
        // 更新加载文字
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            loadingText = "正在检查登录状态..."
        }

        // 设置最小显示时间（确保启动页至少显示 2 秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            minimumTimeElapsed = true
            checkAndFinish()
        }
    }

    /// 检查是否可以结束启动页
    private func checkAndFinish() {
        // 必须同时满足：最小时间已过 + 认证状态已初始化
        if minimumTimeElapsed && authManager.isInitialized {
            withAnimation(.easeInOut(duration: 0.3)) {
                isFinished = true
            }
        }
    }
}

#Preview {
    SplashView(isFinished: .constant(false))
        .environmentObject(AuthManager())
}
