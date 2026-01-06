//
//  ProfileTabView.swift
//  EarthLord
//
//  Created by yanshuang ren on 2026/1/4.
//

import SwiftUI
import Supabase

struct ProfileTabView: View {
    @EnvironmentObject var authManager: AuthManager

    /// 显示登出确认对话框
    @State private var showLogoutConfirmation = false

    /// 显示删除账户确认对话框
    @State private var showDeleteConfirmation = false

    /// 用户输入的确认文字
    @State private var confirmationText = ""

    /// 是否正在删除账户
    @State private var isDeletingAccount = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 深色背景
                Color(red: 0.09, green: 0.09, blue: 0.09)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 用户信息卡片
                        if let user = authManager.currentUser {
                            userInfoCard(user: user)
                                .padding(.top, 20)
                        }

                        // 菜单项列表
                        VStack(spacing: 12) {
                            // 设置 - 导航到设置页面
                            NavigationLink {
                                SettingsView()
                            } label: {
                                menuItemContent(
                                    icon: "gearshape.fill",
                                    title: String(localized: "设置"),
                                    subtitle: String(localized: "账号与隐私设置")
                                )
                            }
                            .buttonStyle(.plain)

                            menuItem(
                                icon: "bell.fill",
                                title: String(localized: "通知"),
                                subtitle: String(localized: "消息提醒设置"),
                                action: { /* TODO: 导航到通知设置 */ }
                            )

                            menuItem(
                                icon: "shield.fill",
                                title: String(localized: "安全"),
                                subtitle: String(localized: "密码与登录安全"),
                                action: { /* TODO: 导航到安全设置 */ }
                            )

                            menuItem(
                                icon: "questionmark.circle.fill",
                                title: String(localized: "帮助"),
                                subtitle: String(localized: "常见问题与反馈"),
                                action: { /* TODO: 导航到帮助页面 */ }
                            )

                            menuItem(
                                icon: "info.circle.fill",
                                title: String(localized: "关于"),
                                subtitle: String(localized: "版本信息"),
                                action: { /* TODO: 导航到关于页面 */ }
                            )
                        }
                        .padding(.horizontal, 16)

                        // 登出按钮
                        Button {
                            showLogoutConfirmation = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 18, weight: .semibold))
                                Text(String(localized: "退出登录"))
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [Color.red, Color.red.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .disabled(authManager.isLoading)

                        // 删除账户按钮
                        Button {
                            print("🔴 点击删除账户按钮")
                            showDeleteConfirmation = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text(String(localized: "删除账户"))
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red, lineWidth: 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.red.opacity(0.1))
                                    )
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                        .disabled(authManager.isLoading)

                        // 加载指示器
                        if authManager.isLoading {
                            ProgressView()
                                .tint(.white)
                                .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "个人中心"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.09, green: 0.09, blue: 0.09), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert(String(localized: "退出登录"), isPresented: $showLogoutConfirmation) {
                Button(String(localized: "取消"), role: .cancel) {}
                Button(String(localized: "退出"), role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
            } message: {
                Text(String(localized: "确定要退出登录吗？"))
            }
            .alert(String(localized: "删除账户"), isPresented: $showDeleteConfirmation) {
                TextField(String(localized: "输入 '删除' 以确认"), text: $confirmationText)
                Button(String(localized: "取消"), role: .cancel) {
                    confirmationText = ""
                    print("❌ 用户取消删除账户")
                }
                Button(String(localized: "确认删除"), role: .destructive) {
                    handleDeleteAccount()
                }
                .disabled(confirmationText.lowercased() != String(localized: "删除").lowercased())
            } message: {
                Text(String(localized: "此操作将永久删除您的账户和所有数据，且无法恢复。\n\n请输入 '删除' 以确认此操作。"))
            }
            .overlay {
                if isDeletingAccount {
                    // 删除中的加载遮罩
                    ZStack {
                        Color.black.opacity(0.7)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)

                            Text(String(localized: "正在删除账户..."))
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                }
            }
        }
    }

    // MARK: - 删除账户处理

    /// 处理删除账户
    private func handleDeleteAccount() {
        print("⚠️ 用户确认删除账户，输入的确认文字: '\(confirmationText)'")

        guard confirmationText.lowercased() == String(localized: "删除").lowercased() else {
            print("❌ 确认文字不匹配，取消删除")
            confirmationText = ""
            return
        }

        print("🔄 开始删除账户流程")

        isDeletingAccount = true
        confirmationText = ""

        Task {
            await authManager.deleteAccount()

            // 删除完成后，等待一小段时间让用户看到加载状态
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

            await MainActor.run {
                isDeletingAccount = false

                if authManager.errorMessage == nil {
                    // 删除成功
                    print("✅ 账户删除成功")
                } else {
                    // 删除失败，显示错误
                    print("❌ 账户删除失败: \(authManager.errorMessage ?? "未知错误")")
                }
            }
        }
    }

    // MARK: - 用户信息卡片
    @ViewBuilder
    private func userInfoCard(user: User) -> some View {
        VStack(spacing: 16) {
            // 头像（显示用户名首字母）
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Text(getUserInitial(email: user.email))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.white)
            }

            // 用户名（从邮箱提取）
            Text(getUserName(email: user.email))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            // 邮箱
            Text(user.email ?? String(localized: "未知邮箱"))
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.7))

            // 用户 ID
            Text(String(localized: "ID: \(user.id.prefix(8))..."))
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - 菜单项

    /// 菜单项内容（用于 NavigationLink）
    @ViewBuilder
    private func menuItemContent(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 文字
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.6))
            }

            Spacer()

            // 箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
        )
    }

    /// 菜单项（按钮版本）
    @ViewBuilder
    private func menuItem(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            menuItemContent(icon: icon, title: title, subtitle: subtitle)
        }
    }

    // MARK: - 辅助方法

    /// 从邮箱提取用户名
    private func getUserName(email: String?) -> String {
        guard let email = email else { return String(localized: "幸存者") }
        return email.components(separatedBy: "@").first ?? String(localized: "幸存者")
    }

    /// 获取用户名首字母（用于头像）
    private func getUserInitial(email: String?) -> String {
        guard let email = email else { return "?" }
        let username = email.components(separatedBy: "@").first ?? ""
        return username.first?.uppercased() ?? "?"
    }
}

#Preview {
    ProfileTabView()
}
