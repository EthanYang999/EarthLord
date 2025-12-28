//
//  AuthView.swift
//  EarthLord
//
//  Created by Ethan on 2025/12/28.
//

import SwiftUI

/// 认证页面
/// 包含登录、注册、忘记密码功能
struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager

    /// 当前选中的Tab（0: 登录, 1: 注册）
    @State private var selectedTab: Int = 0

    /// 是否显示忘记密码弹窗
    @State private var showForgotPassword: Bool = false

    /// Toast 提示信息
    @State private var toastMessage: String?

    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient

            ScrollView {
                VStack(spacing: 32) {
                    // Logo 和标题
                    headerView

                    // Tab 切换
                    tabSelector

                    // 内容区域
                    if selectedTab == 0 {
                        loginView
                    } else {
                        registerView
                    }

                    // 分隔线
                    dividerView

                    // 第三方登录
                    socialLoginView
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 40)
            }

            // 错误提示
            if let error = authManager.errorMessage {
                errorBanner(message: error)
            }

            // Toast 提示
            if let toast = toastMessage {
                toastView(message: toast)
            }

            // 加载遮罩
            if authManager.isLoading {
                loadingOverlay
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet(authManager: authManager)
        }
    }

    // MARK: - 背景渐变
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                ApocalypseTheme.background,
                Color(red: 0.1, green: 0.1, blue: 0.15),
                ApocalypseTheme.background
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - 头部 Logo 和标题
    private var headerView: some View {
        VStack(spacing: 16) {
            // Logo 图标
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // 标题
            Text("地球新主")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("征服世界，从脚下开始")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - Tab 选择器
    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "登录", index: 0)
            tabButton(title: "注册", index: 1)
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
                authManager.resetFlowState()
            }
        } label: {
            Text(title)
                .font(.headline)
                .foregroundColor(selectedTab == index ? ApocalypseTheme.textPrimary : ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selectedTab == index ? ApocalypseTheme.primary : Color.clear)
                .cornerRadius(12)
        }
    }

    // MARK: - 登录视图
    private var loginView: some View {
        LoginFormView(
            authManager: authManager,
            onForgotPassword: { showForgotPassword = true }
        )
    }

    // MARK: - 注册视图
    private var registerView: some View {
        RegisterFormView(authManager: authManager)
    }

    // MARK: - 分隔线
    private var dividerView: some View {
        HStack {
            Rectangle()
                .fill(ApocalypseTheme.textMuted)
                .frame(height: 1)
            Text("或者使用以下方式登录")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .fixedSize()
            Rectangle()
                .fill(ApocalypseTheme.textMuted)
                .frame(height: 1)
        }
        .padding(.top, 8)
    }

    // MARK: - 第三方登录
    private var socialLoginView: some View {
        VStack(spacing: 12) {
            // Apple 登录
            Button {
                showToast("Apple 登录即将开放")
            } label: {
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.title2)
                    Text("通过 Apple 登录")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.black)
                .cornerRadius(12)
            }

            // Google 登录
            Button {
                showToast("Google 登录即将开放")
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.title2)
                    Text("通过 Google 登录")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - 错误横幅
    private func errorBanner(message: String) -> some View {
        VStack {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(message)
                    .font(.subheadline)
                Spacer()
                Button {
                    authManager.clearError()
                } label: {
                    Image(systemName: "xmark")
                }
            }
            .foregroundColor(.white)
            .padding()
            .background(ApocalypseTheme.danger)
            .cornerRadius(12)
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.top, 60)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: authManager.errorMessage)
    }

    // MARK: - Toast 提示
    private func toastView(message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(20)
                .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut, value: toastMessage)
    }

    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            toastMessage = nil
        }
    }

    // MARK: - 加载遮罩
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            ProgressView()
                .scaleEffect(1.5)
                .tint(ApocalypseTheme.primary)
        }
    }
}

// MARK: - 登录表单
struct LoginFormView: View {
    @ObservedObject var authManager: AuthManager

    @State private var email: String = ""
    @State private var password: String = ""

    var onForgotPassword: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // 邮箱输入
            AuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $email,
                keyboardType: .emailAddress
            )

            // 密码输入
            AuthSecureField(
                icon: "lock.fill",
                placeholder: "密码",
                text: $password
            )

            // 登录按钮
            AuthButton(title: "登录", isEnabled: isFormValid) {
                Task {
                    await authManager.signIn(email: email, password: password)
                }
            }

            // 忘记密码
            Button {
                onForgotPassword()
            } label: {
                Text("忘记密码？")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
}

// MARK: - 注册表单（三步流程）
struct RegisterFormView: View {
    @ObservedObject var authManager: AuthManager

    @State private var email: String = ""
    @State private var otpCode: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    /// 重发倒计时
    @State private var resendCountdown: Int = 0
    @State private var countdownTimer: Timer?

    /// 当前步骤（基于 authManager 状态计算）
    private var currentStep: Int {
        if authManager.needsPasswordSetup && authManager.otpVerified {
            return 3  // 设置密码
        } else if authManager.otpSent {
            return 2  // 输入验证码
        } else {
            return 1  // 输入邮箱
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // 步骤指示器
            stepIndicator

            // 根据步骤显示不同内容
            switch currentStep {
            case 1:
                step1EmailView
            case 2:
                step2OTPView
            case 3:
                step3PasswordView
            default:
                EmptyView()
            }
        }
    }

    // MARK: - 步骤指示器
    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { step in
                HStack(spacing: 4) {
                    Circle()
                        .fill(step <= currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("\(step)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(step <= currentStep ? .white : ApocalypseTheme.textMuted)
                        )

                    if step < 3 {
                        Rectangle()
                            .fill(step < currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                            .frame(height: 2)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 第一步：输入邮箱
    private var step1EmailView: some View {
        VStack(spacing: 16) {
            Text("输入您的邮箱")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            AuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $email,
                keyboardType: .emailAddress
            )

            AuthButton(title: "发送验证码", isEnabled: isEmailValid) {
                Task {
                    await authManager.sendRegisterOTP(email: email)
                    startCountdown()
                }
            }
        }
    }

    // MARK: - 第二步：输入验证码
    private var step2OTPView: some View {
        VStack(spacing: 16) {
            Text("输入验证码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("验证码已发送至 \(email)")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 验证码输入
            OTPInputView(code: $otpCode)

            AuthButton(title: "验证", isEnabled: otpCode.count == 6) {
                Task {
                    await authManager.verifyRegisterOTP(email: email, code: otpCode)
                }
            }

            // 重发按钮
            if resendCountdown > 0 {
                Text("重新发送 (\(resendCountdown)s)")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                Button {
                    Task {
                        await authManager.sendRegisterOTP(email: email)
                        startCountdown()
                    }
                } label: {
                    Text("重新发送验证码")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // MARK: - 第三步：设置密码
    private var step3PasswordView: some View {
        VStack(spacing: 16) {
            Text("设置密码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("请设置您的登录密码")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            AuthSecureField(
                icon: "lock.fill",
                placeholder: "密码（至少6位）",
                text: $password
            )

            AuthSecureField(
                icon: "lock.fill",
                placeholder: "确认密码",
                text: $confirmPassword
            )

            if !confirmPassword.isEmpty && password != confirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            AuthButton(title: "完成注册", isEnabled: isPasswordValid) {
                Task {
                    await authManager.completeRegistration(password: password)
                }
            }
        }
    }

    // MARK: - 辅助方法

    private var isEmailValid: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }

    private var isPasswordValid: Bool {
        password.count >= 6 && password == confirmPassword
    }

    private func startCountdown() {
        resendCountdown = 60
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - 忘记密码弹窗
struct ForgotPasswordSheet: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var otpCode: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var resendCountdown: Int = 0
    @State private var countdownTimer: Timer?

    /// 当前步骤
    private var currentStep: Int {
        if authManager.needsPasswordSetup && authManager.otpVerified {
            return 3
        } else if authManager.otpSent {
            return 2
        } else {
            return 1
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 步骤指示
                        Text("步骤 \(currentStep) / 3")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        switch currentStep {
                        case 1:
                            forgotStep1View
                        case 2:
                            forgotStep2View
                        case 3:
                            forgotStep3View
                        default:
                            EmptyView()
                        }

                        // 错误提示
                        if let error = authManager.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.danger)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(ApocalypseTheme.danger.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(24)
                }

                if authManager.isLoading {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    ProgressView().tint(ApocalypseTheme.primary)
                }
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        authManager.resetFlowState()
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - 第一步：输入邮箱
    private var forgotStep1View: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.primary)

            Text("请输入注册时使用的邮箱")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            AuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $email,
                keyboardType: .emailAddress
            )

            AuthButton(title: "发送验证码", isEnabled: isEmailValid) {
                Task {
                    await authManager.sendResetOTP(email: email)
                    startCountdown()
                }
            }
        }
    }

    // MARK: - 第二步：输入验证码
    private var forgotStep2View: some View {
        VStack(spacing: 16) {
            Image(systemName: "number.square.fill")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.primary)

            Text("验证码已发送至 \(email)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            OTPInputView(code: $otpCode)

            AuthButton(title: "验证", isEnabled: otpCode.count == 6) {
                Task {
                    await authManager.verifyResetOTP(email: email, code: otpCode)
                }
            }

            if resendCountdown > 0 {
                Text("重新发送 (\(resendCountdown)s)")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                Button {
                    Task {
                        await authManager.sendResetOTP(email: email)
                        startCountdown()
                    }
                } label: {
                    Text("重新发送验证码")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // MARK: - 第三步：设置新密码
    private var forgotStep3View: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.rotation")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.primary)

            Text("请设置新密码")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            AuthSecureField(
                icon: "lock.fill",
                placeholder: "新密码（至少6位）",
                text: $newPassword
            )

            AuthSecureField(
                icon: "lock.fill",
                placeholder: "确认新密码",
                text: $confirmPassword
            )

            if !confirmPassword.isEmpty && newPassword != confirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            AuthButton(title: "重置密码", isEnabled: isPasswordValid) {
                Task {
                    await authManager.resetPassword(newPassword: newPassword)
                    if authManager.isAuthenticated {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - 辅助方法

    private var isEmailValid: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }

    private var isPasswordValid: Bool {
        newPassword.count >= 6 && newPassword == confirmPassword
    }

    private func startCountdown() {
        resendCountdown = 60
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - 自定义组件

/// 认证文本输入框
struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 20)

            TextField("", text: $text)
                .placeholder(when: text.isEmpty) {
                    Text(placeholder)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .foregroundColor(ApocalypseTheme.textPrimary)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .autocorrectionDisabled()
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

/// 认证密码输入框
struct AuthSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var isSecure: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 20)

            if isSecure {
                SecureField("", text: $text)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .foregroundColor(ApocalypseTheme.textPrimary)
            } else {
                TextField("", text: $text)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .autocapitalization(.none)
            }

            Button {
                isSecure.toggle()
            } label: {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

/// 认证按钮
struct AuthButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    isEnabled ?
                    LinearGradient(
                        colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        colors: [ApocalypseTheme.textMuted, ApocalypseTheme.textMuted],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
        }
        .disabled(!isEnabled)
    }
}

/// OTP 验证码输入
struct OTPInputView: View {
    @Binding var code: String
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // 隐藏的输入框
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0)
                .onChange(of: code) { _, newValue in
                    // 限制为6位数字
                    if newValue.count > 6 {
                        code = String(newValue.prefix(6))
                    }
                    code = newValue.filter { $0.isNumber }
                }

            // 显示的格子
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    let char = index < code.count ? String(code[code.index(code.startIndex, offsetBy: index)]) : ""

                    Text(char)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .frame(width: 45, height: 55)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    index == code.count ? ApocalypseTheme.primary : ApocalypseTheme.textMuted.opacity(0.3),
                                    lineWidth: index == code.count ? 2 : 1
                                )
                        )
                }
            }
            .onTapGesture {
                isFocused = true
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - View Extension for Placeholder
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Preview
#Preview {
    AuthView()
        .environmentObject(AuthManager())
}
