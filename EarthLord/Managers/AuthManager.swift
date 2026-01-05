//
//  AuthManager.swift
//  EarthLord
//
//  Created by yanshuang ren on 2026/1/5.
//

import Foundation
import Combine
import Supabase

/// 用户信息模型
struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
    }
}

/// 认证管理器
/// 负责处理用户注册、登录、密码重置等认证相关功能
@MainActor
class AuthManager: ObservableObject {

    // MARK: - Published Properties

    /// 用户是否已完全认证（已登录且完成所有必需步骤）
    @Published var isAuthenticated: Bool = false

    /// 是否需要设置密码（OTP验证后的强制步骤）
    @Published var needsPasswordSetup: Bool = false

    /// 当前登录用户
    @Published var currentUser: User?

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误消息
    @Published var errorMessage: String?

    /// OTP验证码是否已发送
    @Published var otpSent: Bool = false

    /// OTP验证码是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - Private Properties

    /// Supabase 客户端实例
    private let supabase: SupabaseClient

    // MARK: - Initialization

    init(supabase: SupabaseClient) {
        self.supabase = supabase

        // 初始化时检查会话
        Task {
            await checkSession()
        }
    }

    // MARK: - 注册流程

    /// 发送注册验证码
    /// - Parameter email: 用户邮箱
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 发送 OTP 验证码（允许创建新用户）
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            // 成功发送
            otpSent = true
            print("📧 注册验证码已发送到: \(email)")

        } catch {
            // 处理错误
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            print("❌ 发送注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证注册验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil
        otpVerified = false

        do {
            // 验证 OTP（注册类型使用 .email）
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功，用户已登录，但需要设置密码
            otpVerified = true
            needsPasswordSetup = true
            isAuthenticated = false  // 注意：必须设置密码后才算完全认证

            // 获取用户信息
            await fetchCurrentUser()

            print("✅ 验证码验证成功，用户已登录（待设置密码）")

        } catch {
            // 处理错误
            errorMessage = "验证码验证失败: \(error.localizedDescription)"
            print("❌ 验证注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 完成注册（设置密码）
    /// - Parameter password: 用户设置的密码
    func completeRegistration(password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(
                user: UserAttributes(password: password)
            )

            // 密码设置成功，完成注册流程
            needsPasswordSetup = false
            isAuthenticated = true

            print("✅ 注册完成，密码已设置")

            // 重新获取用户信息
            await fetchCurrentUser()

        } catch {
            // 处理错误
            errorMessage = "设置密码失败: \(error.localizedDescription)"
            print("❌ 完成注册失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 登录流程

    /// 邮箱密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 使用邮箱和密码登录
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            // 登录成功，直接完全认证
            isAuthenticated = true
            needsPasswordSetup = false

            print("✅ 登录成功")

            // 获取用户信息
            await fetchCurrentUser()

        } catch {
            // 处理错误
            errorMessage = "登录失败: \(error.localizedDescription)"
            print("❌ 登录失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 发送密码重置验证码
    /// - Parameter email: 用户邮箱
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 发送密码重置邮件（触发 Reset Password 模板）
            try await supabase.auth.resetPasswordForEmail(email)

            // 成功发送
            otpSent = true
            print("📧 密码重置验证码已发送到: \(email)")

        } catch {
            // 处理错误
            errorMessage = "发送重置验证码失败: \(error.localizedDescription)"
            print("❌ 发送密码重置验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证密码重置验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil
        otpVerified = false

        do {
            // ⚠️ 注意：密码重置使用 .recovery 类型，不是 .email
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )

            // 验证成功，用户已登录，等待设置新密码
            otpVerified = true
            needsPasswordSetup = true
            isAuthenticated = false  // 需要设置新密码后才算完全认证

            // 获取用户信息
            await fetchCurrentUser()

            print("✅ 重置验证码验证成功（待设置新密码）")

        } catch {
            // 处理错误
            errorMessage = "验证码验证失败: \(error.localizedDescription)"
            print("❌ 验证重置验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 重置密码（设置新密码）
    /// - Parameter newPassword: 新密码
    func resetPassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )

            // 密码重置成功
            needsPasswordSetup = false
            isAuthenticated = true

            print("✅ 密码重置成功")

            // 重新获取用户信息
            await fetchCurrentUser()

        } catch {
            // 处理错误
            errorMessage = "重置密码失败: \(error.localizedDescription)"
            print("❌ 重置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// Apple 登录
    /// TODO: 实现 Sign in with Apple 功能
    func signInWithApple() async {
        // TODO: 集成 Apple 登录
        print("⚠️ Apple 登录功能待实现")
        errorMessage = "Apple 登录功能暂未开放"
    }

    /// Google 登录
    /// TODO: 实现 Sign in with Google 功能
    func signInWithGoogle() async {
        // TODO: 集成 Google 登录
        print("⚠️ Google 登录功能待实现")
        errorMessage = "Google 登录功能暂未开放"
    }

    // MARK: - 其他方法

    /// 登出
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            // 调用 Supabase 登出
            try await supabase.auth.signOut()

            // 重置所有状态
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false

            print("✅ 已登出")

        } catch {
            // 处理错误
            errorMessage = "登出失败: \(error.localizedDescription)"
            print("❌ 登出失败: \(error)")
        }

        isLoading = false
    }

    /// 检查会话状态
    /// 在应用启动时调用，恢复用户登录状态
    func checkSession() async {
        isLoading = true

        do {
            // 获取当前会话
            let _ = try await supabase.auth.session

            // 有有效会话
            await fetchCurrentUser()

            // 检查用户是否已设置密码
            // 注意：这里需要根据实际情况判断
            // 如果用户是通过邮箱密码登录的，则已完成所有步骤
            isAuthenticated = true
            needsPasswordSetup = false

            print("✅ 检测到有效会话，自动登录")

        } catch {
            // 没有会话或会话过期
            isAuthenticated = false
            currentUser = nil
            print("ℹ️ 会话检查: 未登录或会话已过期")
        }

        isLoading = false
    }

    // MARK: - Private Methods

    /// 获取当前用户信息
    private func fetchCurrentUser() async {
        do {
            // 获取当前登录用户
            let authUser = try await supabase.auth.user()

            // 转换为自定义 User 模型
            currentUser = User(
                id: authUser.id.uuidString,
                email: authUser.email,
                createdAt: authUser.createdAt
            )

            print("👤 当前用户: \(authUser.email ?? "未知")")

        } catch {
            print("❌ 获取用户信息失败: \(error)")
            currentUser = nil
        }
    }

    /// 重置错误消息
    func clearError() {
        errorMessage = nil
    }

    /// 重置 OTP 相关状态（用于重新发送验证码）
    func resetOTPState() {
        otpSent = false
        otpVerified = false
        errorMessage = nil
    }
}
