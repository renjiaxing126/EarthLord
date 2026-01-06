//
//  SettingsView.swift
//  EarthLord
//
//  Created by Claude Code on 2026/1/5.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    /// 显示删除账户确认对话框
    @State private var showDeleteConfirmation = false

    /// 用户输入的确认文字
    @State private var confirmationText = ""

    /// 是否正在删除账户
    @State private var isDeletingAccount = false

    var body: some View {
        ZStack {
            // 深色背景
            Color(red: 0.09, green: 0.09, blue: 0.09)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 账号与隐私设置区域
                    VStack(spacing: 12) {
                        sectionHeader(title: "账号与隐私")

                        settingItem(
                            icon: "person.fill",
                            title: "个人资料",
                            subtitle: "编辑用户名、头像",
                            action: { /* TODO */ }
                        )

                        settingItem(
                            icon: "lock.fill",
                            title: "修改密码",
                            subtitle: "更改登录密码",
                            action: { /* TODO */ }
                        )

                        settingItem(
                            icon: "eye.slash.fill",
                            title: "隐私设置",
                            subtitle: "控制信息可见性",
                            action: { /* TODO */ }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                    // 危险区域
                    VStack(spacing: 12) {
                        sectionHeader(title: "危险区域")

                        // 删除账户按钮
                        Button {
                            print("🔴 点击删除账户按钮")
                            showDeleteConfirmation = true
                        } label: {
                            HStack(spacing: 16) {
                                // 图标
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.2))
                                        .frame(width: 44, height: 44)

                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.red)
                                }

                                // 文字
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("删除账户")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.red)

                                    Text("永久删除账户和所有数据")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color.red.opacity(0.7))
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.red.opacity(0.5))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // 底部间距
                    Spacer()
                        .frame(height: 40)
                }
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 0.09, green: 0.09, blue: 0.09), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("删除账户", isPresented: $showDeleteConfirmation) {
            TextField("输入 '删除' 以确认", text: $confirmationText)
            Button("取消", role: .cancel) {
                confirmationText = ""
                print("❌ 用户取消删除账户")
            }
            Button("确认删除", role: .destructive) {
                handleDeleteAccount()
            }
            .disabled(confirmationText != "删除")
        } message: {
            Text("此操作将永久删除您的账户和所有数据，且无法恢复。\n\n请输入 '删除' 以确认此操作。")
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

                        Text("正在删除账户...")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
        }
    }

    // MARK: - 组件

    /// 区域标题
    @ViewBuilder
    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.6))
                .textCase(.uppercase)

            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    /// 设置项
    @ViewBuilder
    private func settingItem(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
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

    // MARK: - 方法

    /// 处理删除账户
    private func handleDeleteAccount() {
        print("⚠️ 用户确认删除账户，输入的确认文字: '\(confirmationText)'")

        guard confirmationText == "删除" else {
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
                    // 删除成功，关闭页面
                    print("✅ 账户删除成功，关闭设置页面")
                    dismiss()
                } else {
                    // 删除失败，显示错误
                    print("❌ 账户删除失败: \(authManager.errorMessage ?? "未知错误")")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthManager(supabase: SupabaseService.shared))
    }
}
