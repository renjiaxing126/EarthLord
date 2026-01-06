//
//  AuthView.swift
//  EarthLord
//
//  Created by yanshuang ren on 2026/1/5.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var languageManager: LanguageManager

    // Tab 选择
    @State private var selectedTab: AuthTab = .login

    // 登录表单
    @State private var loginEmail = ""
    @State private var loginPassword = ""

    // 注册表单
    @State private var registerEmail = ""
    @State private var registerOTP = ""
    @State private var registerPassword = ""
    @State private var registerConfirmPassword = ""

    // 忘记密码弹窗
    @State private var showForgotPassword = false
    @State private var forgotPasswordEmail = ""
    @State private var forgotPasswordOTP = ""
    @State private var forgotPasswordNew = ""
    @State private var forgotPasswordConfirm = ""

    // 倒计时
    @State private var resendCountdown = 0
    @State private var forgotResendCountdown = 0

    var body: some View {
        ZStack {
            // 深色渐变背景
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

            ScrollView {
                VStack(spacing: 30) {
                    Spacer()
                        .frame(height: 60)

                    // Logo 和标题
                    logoSection

                    // Tab 切换
                    tabSelector

                    // 内容区域
                    contentSection
                        .padding(.horizontal, 24)

                    // 第三方登录
                    thirdPartyLoginSection
                        .padding(.horizontal, 24)

                    Spacer()
                        .frame(height: 40)
                }
            }

            // 加载指示器
            if authManager.isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        VStack(spacing: 16) {
            // Logo
            ZStack {
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
                    .frame(width: 100, height: 100)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 20)

                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }

            // 标题
            VStack(spacing: 4) {
                LocalizedText(key: "地球新主")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("EARTH LORD")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .tracking(3)
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(AuthTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                        // 切换 tab 时重置状态
                        resetTabState()
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.title)
                            .font(.system(size: 18, weight: selectedTab == tab ? .bold : .regular))
                            .foregroundColor(selectedTab == tab ? ApocalypseTheme.textPrimary : ApocalypseTheme.textSecondary)

                        Rectangle()
                            .fill(selectedTab == tab ? ApocalypseTheme.primary : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(spacing: 20) {
            // 错误提示
            if let error = authManager.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                        .font(.subheadline)
                }
                .foregroundColor(.red)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            // 根据选中的 tab 显示内容
            if selectedTab == .login {
                loginForm
            } else {
                registerForm
            }
        }
    }

    // MARK: - Login Form

    private var loginForm: some View {
        VStack(spacing: 16) {
            // 邮箱输入框
            CustomTextField(
                icon: "envelope",
                placeholder: "邮箱".appLocalized,
                text: $loginEmail
            )
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)

            // 密码输入框
            CustomSecureField(
                icon: "lock",
                placeholder: "密码".appLocalized,
                text: $loginPassword
            )

            // 忘记密码
            HStack {
                Spacer()
                Button {
                    showForgotPassword = true
                } label: {
                    LocalizedText(key: "忘记密码？")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }

            // 登录按钮
            Button {
                Task {
                    await authManager.signIn(email: loginEmail, password: loginPassword)
                }
            } label: {
                LocalizedText(key: "登录")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(loginEmail.isEmpty || loginPassword.isEmpty || authManager.isLoading)
            .opacity(loginEmail.isEmpty || loginPassword.isEmpty || authManager.isLoading ? 0.6 : 1)
        }
    }

    // MARK: - Register Form

    private var registerForm: some View {
        VStack(spacing: 16) {
            if !authManager.otpSent {
                // 第一步：输入邮箱
                registerStep1
            } else if !authManager.otpVerified {
                // 第二步：验证 OTP
                registerStep2
            } else if authManager.needsPasswordSetup {
                // 第三步：设置密码
                registerStep3
            }
        }
    }

    // 注册第一步：邮箱输入
    private var registerStep1: some View {
        VStack(spacing: 16) {
            LocalizedText(key: "步骤 1/3：输入邮箱")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            CustomTextField(
                icon: "envelope",
                placeholder: "邮箱".appLocalized,
                text: $registerEmail
            )
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)

            Button {
                Task {
                    await authManager.sendRegisterOTP(email: registerEmail)
                    if authManager.otpSent {
                        startResendCountdown()
                    }
                }
            } label: {
                LocalizedText(key: "发送验证码")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(registerEmail.isEmpty || authManager.isLoading)
            .opacity(registerEmail.isEmpty || authManager.isLoading ? 0.6 : 1)
        }
    }

    // 注册第二步：验证码输入
    private var registerStep2: some View {
        VStack(spacing: 16) {
            LocalizedText(key: "步骤 2/3：验证邮箱")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("验证码已发送到 \(registerEmail)".appLocalized)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            CustomTextField(
                icon: "number",
                placeholder: "6位验证码".appLocalized,
                text: $registerOTP
            )
            .keyboardType(.numberPad)

            // 重发倒计时
            if resendCountdown > 0 {
                Text("\(resendCountdown)秒后可重新发送".appLocalized)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Button {
                    Task {
                        authManager.resetOTPState()
                        registerOTP = ""
                        await authManager.sendRegisterOTP(email: registerEmail)
                        if authManager.otpSent {
                            startResendCountdown()
                        }
                    }
                } label: {
                    LocalizedText(key: "重新发送验证码")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.primary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Button {
                Task {
                    await authManager.verifyRegisterOTP(email: registerEmail, code: registerOTP)
                }
            } label: {
                LocalizedText(key: "验证")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(registerOTP.isEmpty || authManager.isLoading)
            .opacity(registerOTP.isEmpty || authManager.isLoading ? 0.6 : 1)
        }
    }

    // 注册第三步：设置密码
    private var registerStep3: some View {
        VStack(spacing: 16) {
            LocalizedText(key: "步骤 3/3：设置密码")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LocalizedText(key: "验证成功！请设置您的密码")
                .font(.caption)
                .foregroundColor(.green)
                .frame(maxWidth: .infinity, alignment: .leading)

            CustomSecureField(
                icon: "lock",
                placeholder: "密码（至少6位）".appLocalized,
                text: $registerPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认密码".appLocalized,
                text: $registerConfirmPassword
            )

            // 密码匹配提示
            if !registerConfirmPassword.isEmpty && registerPassword != registerConfirmPassword {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    LocalizedText(key: "两次密码不一致")
                        .font(.caption)
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task {
                    await authManager.completeRegistration(password: registerPassword)
                }
            } label: {
                LocalizedText(key: "完成注册")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(!isPasswordValid || authManager.isLoading)
            .opacity(!isPasswordValid || authManager.isLoading ? 0.6 : 1)
        }
    }

    // MARK: - Third Party Login Section

    private var thirdPartyLoginSection: some View {
        VStack(spacing: 20) {
            // 分隔线
            HStack {
                Rectangle()
                    .fill(ApocalypseTheme.textSecondary.opacity(0.3))
                    .frame(height: 1)

                LocalizedText(key: "或者使用以下方式登录")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(.horizontal, 12)

                Rectangle()
                    .fill(ApocalypseTheme.textSecondary.opacity(0.3))
                    .frame(height: 1)
            }

            VStack(spacing: 12) {
                // Apple 登录按钮
                Button {
                    showComingSoonToast(provider: "Apple")
                } label: {
                    HStack {
                        Image(systemName: "apple.logo")
                            .font(.title3)
                        LocalizedText(key: "使用 Apple 登录")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }

                // Google 登录按钮
                Button {
                    showComingSoonToast(provider: "Google")
                } label: {
                    HStack {
                        Image(systemName: "globe")
                            .font(.title3)
                        LocalizedText(key: "使用 Google 登录")
                            .font(.headline)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Forgot Password Sheet

    private var forgotPasswordSheet: some View {
        NavigationStack {
            ZStack {
                // 背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.10, green: 0.10, blue: 0.18),
                        Color(red: 0.09, green: 0.13, blue: 0.24)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 错误提示
                        if let error = authManager.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(error)
                                    .font(.subheadline)
                            }
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }

                        if !authManager.otpSent {
                            // 第一步：输入邮箱
                            forgotPasswordStep1
                        } else if !authManager.otpVerified {
                            // 第二步：验证 OTP
                            forgotPasswordStep2
                        } else if authManager.needsPasswordSetup {
                            // 第三步：设置新密码
                            forgotPasswordStep3
                        }
                    }
                    .padding(24)
                }

                // 加载指示器
                if authManager.isLoading {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
            .navigationTitle("找回密码".appLocalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showForgotPassword = false
                        resetForgotPasswordState()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                }
            }
        }
    }

    // 忘记密码第一步
    private var forgotPasswordStep1: some View {
        VStack(spacing: 16) {
            LocalizedText(key: "步骤 1/3：输入邮箱")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            CustomTextField(
                icon: "envelope",
                placeholder: "邮箱".appLocalized,
                text: $forgotPasswordEmail
            )
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)

            Button {
                Task {
                    await authManager.sendResetOTP(email: forgotPasswordEmail)
                    if authManager.otpSent {
                        startForgotResendCountdown()
                    }
                }
            } label: {
                LocalizedText(key: "发送验证码")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(forgotPasswordEmail.isEmpty || authManager.isLoading)
            .opacity(forgotPasswordEmail.isEmpty || authManager.isLoading ? 0.6 : 1)
        }
    }

    // 忘记密码第二步
    private var forgotPasswordStep2: some View {
        VStack(spacing: 16) {
            LocalizedText(key: "步骤 2/3：验证邮箱")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("验证码已发送到 \(forgotPasswordEmail)".appLocalized)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            CustomTextField(
                icon: "number",
                placeholder: "6位验证码".appLocalized,
                text: $forgotPasswordOTP
            )
            .keyboardType(.numberPad)

            // 重发倒计时
            if forgotResendCountdown > 0 {
                Text("\(forgotResendCountdown)秒后可重新发送".appLocalized)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Button {
                    Task {
                        authManager.resetOTPState()
                        forgotPasswordOTP = ""
                        await authManager.sendResetOTP(email: forgotPasswordEmail)
                        if authManager.otpSent {
                            startForgotResendCountdown()
                        }
                    }
                } label: {
                    LocalizedText(key: "重新发送验证码")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.primary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Button {
                Task {
                    await authManager.verifyResetOTP(email: forgotPasswordEmail, code: forgotPasswordOTP)
                }
            } label: {
                LocalizedText(key: "验证")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(forgotPasswordOTP.isEmpty || authManager.isLoading)
            .opacity(forgotPasswordOTP.isEmpty || authManager.isLoading ? 0.6 : 1)
        }
    }

    // 忘记密码第三步
    private var forgotPasswordStep3: some View {
        VStack(spacing: 16) {
            LocalizedText(key: "步骤 3/3：设置新密码")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LocalizedText(key: "验证成功！请设置新密码")
                .font(.caption)
                .foregroundColor(.green)
                .frame(maxWidth: .infinity, alignment: .leading)

            CustomSecureField(
                icon: "lock",
                placeholder: "新密码（至少6位）".appLocalized,
                text: $forgotPasswordNew
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认新密码".appLocalized,
                text: $forgotPasswordConfirm
            )

            // 密码匹配提示
            if !forgotPasswordConfirm.isEmpty && forgotPasswordNew != forgotPasswordConfirm {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    LocalizedText(key: "两次密码不一致")
                        .font(.caption)
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task {
                    await authManager.resetPassword(newPassword: forgotPasswordNew)
                    if authManager.isAuthenticated {
                        showForgotPassword = false
                        resetForgotPasswordState()
                    }
                }
            } label: {
                LocalizedText(key: "重置密码")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(!isForgotPasswordValid || authManager.isLoading)
            .opacity(!isForgotPasswordValid || authManager.isLoading ? 0.6 : 1)
        }
    }

    // MARK: - Helper Methods

    /// 密码是否有效
    private var isPasswordValid: Bool {
        registerPassword.count >= 6 &&
        registerPassword == registerConfirmPassword
    }

    /// 忘记密码表单是否有效
    private var isForgotPasswordValid: Bool {
        forgotPasswordNew.count >= 6 &&
        forgotPasswordNew == forgotPasswordConfirm
    }

    /// 开始注册重发倒计时
    private func startResendCountdown() {
        resendCountdown = 60
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }

    /// 开始忘记密码重发倒计时
    private func startForgotResendCountdown() {
        forgotResendCountdown = 60
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if forgotResendCountdown > 0 {
                forgotResendCountdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }

    /// 重置 Tab 状态
    private func resetTabState() {
        authManager.resetOTPState()
        authManager.clearError()

        // 清空表单
        loginEmail = ""
        loginPassword = ""
        registerEmail = ""
        registerOTP = ""
        registerPassword = ""
        registerConfirmPassword = ""

        resendCountdown = 0
    }

    /// 重置忘记密码状态
    private func resetForgotPasswordState() {
        authManager.resetOTPState()
        authManager.clearError()

        forgotPasswordEmail = ""
        forgotPasswordOTP = ""
        forgotPasswordNew = ""
        forgotPasswordConfirm = ""
        forgotResendCountdown = 0
    }

    /// 显示即将开放提示
    private func showComingSoonToast(provider: String) {
        authManager.errorMessage = "\(provider) 登录即将开放"

        // 2秒后清除提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            authManager.clearError()
        }
    }
}

// MARK: - Auth Tab Enum

enum AuthTab: CaseIterable {
    case login
    case register

    var title: String {
        switch self {
        case .login: return "登录".appLocalized
        case .register: return "注册".appLocalized
        }
    }
}

// MARK: - Custom Text Field

struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .accentColor(ApocalypseTheme.primary)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Custom Secure Field

struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 20)

            SecureField(placeholder, text: $text)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .accentColor(ApocalypseTheme.primary)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    AuthView()
}
