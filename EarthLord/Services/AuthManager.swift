//
//  AuthManager.swift
//  EarthLord
//
//  Created by Ethan on 2025/12/26.
//

import Foundation
import Combine
import Supabase

/// 认证管理器
/// 负责处理用户注册、登录、密码重置等认证相关操作
///
/// 认证流程说明：
/// - 注册：发验证码 → 验证OTP（此时已登录但无密码）→ 强制设置密码 → 完成
/// - 登录：邮箱 + 密码（直接登录）
/// - 找回密码：发验证码 → 验证OTP（此时已登录）→ 设置新密码 → 完成
@MainActor
class AuthManager: ObservableObject {

    // MARK: - 发布属性

    /// 是否已完成认证（已登录且完成所有必要流程）
    @Published var isAuthenticated: Bool = false

    /// 是否需要设置密码（OTP验证后、设置密码前的状态）
    @Published var needsPasswordSetup: Bool = false

    /// 当前登录用户
    @Published var currentUser: User?

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 验证码是否已发送
    @Published var otpSent: Bool = false

    /// 验证码是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - 初始化

    init() {
        // 启动时检查现有会话
        Task {
            await checkSession()
        }
    }

    // MARK: - 注册流程

    /// 发送注册验证码
    /// - Parameter email: 用户邮箱
    /// - Note: 使用 signInWithOTP 并设置 shouldCreateUser 为 true
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )
            otpSent = true
            print("[AuthManager] 注册验证码已发送到: \(email)")
        } catch {
            errorMessage = handleAuthError(error)
            print("[AuthManager] 发送注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证注册验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    /// - Note: 验证成功后用户已登录，但 isAuthenticated 保持 false，需要设置密码
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功，用户已登录
            currentUser = response.user
            otpVerified = true
            needsPasswordSetup = true
            // 注意：isAuthenticated 保持 false，必须设置密码后才能进入主页

            print("[AuthManager] 注册验证码验证成功，等待设置密码")
        } catch {
            errorMessage = handleAuthError(error)
            print("[AuthManager] 验证注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 完成注册（设置密码）
    /// - Parameter password: 用户设置的密码
    /// - Note: 必须在 verifyRegisterOTP 成功后调用
    func completeRegistration(password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // update 返回的直接是 User 类型
            let user = try await supabase.auth.update(
                user: UserAttributes(password: password)
            )

            currentUser = user
            needsPasswordSetup = false
            otpVerified = false
            otpSent = false
            isAuthenticated = true

            print("[AuthManager] 注册完成，密码设置成功")
        } catch {
            errorMessage = handleAuthError(error)
            print("[AuthManager] 设置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 登录

    /// 邮箱密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            currentUser = response.user
            isAuthenticated = true

            print("[AuthManager] 登录成功: \(email)")
        } catch {
            errorMessage = handleAuthError(error)
            print("[AuthManager] 登录失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 发送密码重置验证码
    /// - Parameter email: 用户邮箱
    /// - Note: 会触发 Reset Password 邮件模板
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.resetPasswordForEmail(email)
            otpSent = true

            print("[AuthManager] 密码重置验证码已发送到: \(email)")
        } catch {
            errorMessage = handleAuthError(error)
            print("[AuthManager] 发送密码重置验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证密码重置验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    /// - Note: 注意 type 是 .recovery 不是 .email
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery  // 重要：找回密码使用 .recovery 类型
            )

            currentUser = response.user
            otpVerified = true
            needsPasswordSetup = true

            print("[AuthManager] 密码重置验证码验证成功，等待设置新密码")
        } catch {
            errorMessage = handleAuthError(error)
            print("[AuthManager] 验证密码重置验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 重置密码（设置新密码）
    /// - Parameter newPassword: 新密码
    /// - Note: 必须在 verifyResetOTP 成功后调用
    func resetPassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // update 返回的直接是 User 类型
            let user = try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )

            currentUser = user
            needsPasswordSetup = false
            otpVerified = false
            otpSent = false
            isAuthenticated = true

            print("[AuthManager] 密码重置成功")
        } catch {
            errorMessage = handleAuthError(error)
            print("[AuthManager] 重置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// Apple 登录
    /// - TODO: 实现 Sign in with Apple
    func signInWithApple() async {
        // TODO: 实现 Apple 登录
        // 1. 使用 AuthenticationServices 获取 Apple ID credential
        // 2. 调用 supabase.auth.signInWithIdToken(credentials:)
        print("[AuthManager] Apple 登录 - 待实现")
    }

    /// Google 登录
    /// - TODO: 实现 Sign in with Google
    func signInWithGoogle() async {
        // TODO: 实现 Google 登录
        // 1. 使用 Google Sign-In SDK 获取 ID token
        // 2. 调用 supabase.auth.signInWithIdToken(credentials:)
        print("[AuthManager] Google 登录 - 待实现")
    }

    // MARK: - 其他方法

    /// 退出登录
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signOut()

            // 重置所有状态
            currentUser = nil
            isAuthenticated = false
            needsPasswordSetup = false
            otpSent = false
            otpVerified = false

            print("[AuthManager] 已退出登录")
        } catch {
            errorMessage = handleAuthError(error)
            print("[AuthManager] 退出登录失败: \(error)")
        }

        isLoading = false
    }

    /// 检查现有会话
    /// - Note: 应用启动时调用，恢复登录状态
    func checkSession() async {
        isLoading = true

        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            isAuthenticated = true

            print("[AuthManager] 已恢复会话: \(session.user.email ?? "未知邮箱")")
        } catch {
            // 没有有效会话，保持未登录状态
            currentUser = nil
            isAuthenticated = false
            print("[AuthManager] 无有效会话")
        }

        isLoading = false
    }

    /// 重置流程状态
    /// - Note: 用于取消当前流程，返回初始状态
    func resetFlowState() {
        otpSent = false
        otpVerified = false
        needsPasswordSetup = false
        errorMessage = nil
    }

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    // MARK: - 私有方法

    /// 处理认证错误，返回用户友好的错误信息
    private func handleAuthError(_ error: Error) -> String {
        let errorString = String(describing: error)

        // 常见错误映射
        if errorString.contains("Invalid login credentials") {
            return "邮箱或密码错误"
        } else if errorString.contains("Email not confirmed") {
            return "邮箱未验证"
        } else if errorString.contains("User already registered") {
            return "该邮箱已注册"
        } else if errorString.contains("Invalid OTP") || errorString.contains("Token has expired") {
            return "验证码无效或已过期"
        } else if errorString.contains("Email rate limit exceeded") {
            return "发送过于频繁，请稍后再试"
        } else if errorString.contains("Password should be at least") {
            return "密码长度不足，至少需要6位"
        } else if errorString.contains("network") || errorString.contains("NSURLErrorDomain") {
            return "网络连接失败，请检查网络"
        } else {
            return "操作失败：\(error.localizedDescription)"
        }
    }
}
