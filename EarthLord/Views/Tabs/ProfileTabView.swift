//
//  ProfileTabView.swift
//  EarthLord
//
//  Created by yanshuang ren on 2026/1/4.
//

import SwiftUI

struct ProfileTabView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 用户信息
                if let user = authManager.currentUser {
                    VStack(spacing: 8) {
                        // 头像
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            )

                        // 用户名/邮箱
                        Text(user.email ?? "幸存者")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("ID: \(user.id.prefix(8))...")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .padding(.top, 40)
                }

                Spacer()

                // 登出按钮
                Button {
                    Task {
                        await authManager.signOut()
                    }
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("登出")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)

                // 加载指示器
                if authManager.isLoading {
                    ProgressView()
                }
            }
            .navigationTitle("个人")
        }
    }
}

#Preview {
    ProfileTabView()
}
