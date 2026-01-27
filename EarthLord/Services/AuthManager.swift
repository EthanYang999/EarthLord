//
//  AuthManager.swift
//  EarthLord
//
//  Created by Ethan on 2025/12/26.
//

import Foundation
import Combine
import Supabase
import GoogleSignIn

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

    /// 是否已完成初始化检查
    @Published var isInitialized: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 验证码是否已发送
    @Published var otpSent: Bool = false

    /// 验证码是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - 私有属性

    /// 认证状态监听任务
    private var authStateTask: Task<Void, Never>?

    // MARK: - 初始化

    init() {
        // 启动认证状态监听
        startAuthStateListener()
    }

    deinit {
        // 取消监听任务
        authStateTask?.cancel()
    }

    // MARK: - 认证状态监听

    /// 启动认证状态变化监听
    /// - Note: 监听 Supabase 的 authStateChanges，自动处理登录/登出状态
    private func startAuthStateListener() {
        authStateTask = Task { [weak self] in
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self = self else { break }

                await MainActor.run {
                    self.handleAuthStateChange(event: event, session: session)
                }
            }
        }
    }

    /// 处理认证状态变化
    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) {
        print("[AuthManager] 认证状态变化: \(event)")

        switch event {
        case .initialSession:
            // 初始会话检查
            if let session = session {
                currentUser = session.user
                isAuthenticated = true
                print("[AuthManager] 初始会话: 已登录 - \(session.user.email ?? "未知邮箱")")
            } else {
                currentUser = nil
                isAuthenticated = false
                print("[AuthManager] 初始会话: 未登录")
            }
            isInitialized = true

        case .signedIn:
            // 用户登录
            if let session = session {
                currentUser = session.user
                // 只有在不需要设置密码时才设置为已认证
                if !needsPasswordSetup {
                    isAuthenticated = true
                }
                print("[AuthManager] 用户登录: \(session.user.email ?? "未知邮箱")")
            }

        case .signedOut:
            // 用户登出
            currentUser = nil
            isAuthenticated = false
            needsPasswordSetup = false
            otpSent = false
            otpVerified = false
            print("[AuthManager] 用户已登出")

        case .tokenRefreshed:
            // Token 刷新
            if let session = session {
                currentUser = session.user
                print("[AuthManager] Token 已刷新")
            }

        case .userUpdated:
            // 用户信息更新
            if let session = session {
                currentUser = session.user
                print("[AuthManager] 用户信息已更新")
            }

        case .passwordRecovery:
            // 密码恢复流程
            print("[AuthManager] 密码恢复流程")

        default:
            print("[AuthManager] 其他认证事件: \(event)")
        }
    }

    // MARK: - 注册流程

    /// 检查邮箱是否已注册
    /// - Parameter email: 用户邮箱
    /// - Returns: 是否已注册
    private func checkEmailExists(email: String) async throws -> Bool {
        let url = URL(string: "https://bilzmsorvemxztftlzsp.supabase.co/functions/v1/check-email-exists")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["email": email])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.custom("检查邮箱失败")
        }

        let result = try JSONDecoder().decode([String: Bool].self, from: data)
        return result["exists"] ?? false
    }

    /// 发送注册验证码
    /// - Parameter email: 用户邮箱
    /// - Note: 先检查邮箱是否已注册，如果已注册则提示用户直接登录
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 先检查邮箱是否已注册
            let emailExists = try await checkEmailExists(email: email)

            if emailExists {
                errorMessage = "该邮箱已注册，请直接登录"
                print("[AuthManager] 邮箱已注册: \(email)")
                isLoading = false
                return
            }

            // 邮箱未注册，发送验证码
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
    /// - Note: 使用 GoogleSignIn SDK 获取 ID Token，然后通过 Supabase 验证
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        do {
            // 1. 获取当前窗口场景的根视图控制器
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                throw AuthError.custom("无法获取根视图控制器")
            }

            // 2. 调用 Google Sign-In
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            // 3. 获取 ID Token
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.custom("无法获取 Google ID Token")
            }

            // 4. 使用 ID Token 登录 Supabase
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken
                )
            )

            currentUser = session.user
            isAuthenticated = true

            print("[AuthManager] Google 登录成功: \(session.user.email ?? "未知邮箱")")
        } catch let error as GIDSignInError {
            // 处理 Google Sign-In 特定错误
            switch error.code {
            case .canceled:
                print("[AuthManager] 用户取消了 Google 登录")
                // 用户取消不显示错误
            case .hasNoAuthInKeychain:
                errorMessage = "没有保存的 Google 登录信息"
            default:
                errorMessage = "Google 登录失败：\(error.localizedDescription)"
            }
        } catch {
            errorMessage = handleAuthError(error)
            print("[AuthManager] Google 登录失败: \(error)")
        }

        isLoading = false
    }

    /// 自定义认证错误类型
    enum AuthError: LocalizedError {
        case custom(String)

        var errorDescription: String? {
            switch self {
            case .custom(let message):
                return message
            }
        }
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

    /// 删除账户
    /// - Note: 调用边缘函数删除用户账户，此操作不可逆
    /// - Returns: 是否删除成功
    @discardableResult
    func deleteAccount() async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            // 1. 获取当前会话
            let session = try await supabase.auth.session

            // 2. 构建请求
            let url = URL(string: "https://bilzmsorvemxztftlzsp.supabase.co/functions/v1/delete-account")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // 3. 发送请求
            let (data, response) = try await URLSession.shared.data(for: request)

            // 4. 检查响应状态
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.custom("无效的服务器响应")
            }

            // 5. 解析响应
            if httpResponse.statusCode == 200 {
                // 删除成功，清空本地状态
                currentUser = nil
                isAuthenticated = false
                needsPasswordSetup = false
                otpSent = false
                otpVerified = false

                print("[AuthManager] 账户已成功删除")
                isLoading = false
                return true
            } else {
                // 解析错误信息
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMsg = json["error"] as? String {
                    throw AuthError.custom(errorMsg)
                } else {
                    throw AuthError.custom("删除账户失败，状态码: \(httpResponse.statusCode)")
                }
            }
        } catch {
            errorMessage = "删除账户失败：\(error.localizedDescription)"
            print("[AuthManager] 删除账户失败: \(error)")
            isLoading = false
            return false
        }
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
        } else if errorString.contains("same_password") || errorString.contains("different from the old password") {
            return "新密码不能与旧密码相同"
        } else if errorString.contains("network") || errorString.contains("NSURLErrorDomain") {
            return "网络连接失败，请检查网络"
        } else {
            return "操作失败：\(error.localizedDescription)"
        }
    }
}
