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
                            menuItem(
                                icon: "gearshape.fill",
                                title: "设置",
                                subtitle: "账号与隐私设置",
                                action: { /* TODO: 导航到设置页面 */ }
                            )

                            menuItem(
                                icon: "bell.fill",
                                title: "通知",
                                subtitle: "消息提醒设置",
                                action: { /* TODO: 导航到通知设置 */ }
                            )

                            menuItem(
                                icon: "shield.fill",
                                title: "安全",
                                subtitle: "密码与登录安全",
                                action: { /* TODO: 导航到安全设置 */ }
                            )

                            menuItem(
                                icon: "questionmark.circle.fill",
                                title: "帮助",
                                subtitle: "常见问题与反馈",
                                action: { /* TODO: 导航到帮助页面 */ }
                            )

                            menuItem(
                                icon: "info.circle.fill",
                                title: "关于",
                                subtitle: "版本信息",
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
                                Text("退出登录")
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
            .navigationTitle("个人中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.09, green: 0.09, blue: 0.09), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("退出登录", isPresented: $showLogoutConfirmation) {
                Button("取消", role: .cancel) {}
                Button("退出", role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
            } message: {
                Text("确定要退出登录吗？")
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
            Text(user.email ?? "未知邮箱")
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.7))

            // 用户 ID
            Text("ID: \(user.id.prefix(8))...")
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
    @ViewBuilder
    private func menuItem(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
    }

    // MARK: - 辅助方法

    /// 从邮箱提取用户名
    private func getUserName(email: String?) -> String {
        guard let email = email else { return "幸存者" }
        return email.components(separatedBy: "@").first ?? "幸存者"
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
