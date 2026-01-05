//
//  RootView.swift
//  EarthLord
//
//  Created by yanshuang ren on 2026/1/4.
//

import SwiftUI

/// 根视图：控制启动页、认证页与主界面的切换
struct RootView: View {
    /// 认证管理器
    @StateObject private var authManager = AuthManager(supabase: SupabaseService.shared)

    /// 启动页是否完成
    @State private var splashFinished = false

    var body: some View {
        ZStack {
            if !splashFinished {
                // 启动页
                SplashView(isFinished: $splashFinished)
                    .transition(.opacity)
            } else {
                // 根据认证状态显示不同界面
                if authManager.isAuthenticated {
                    // 已完全认证 → 主界面
                    MainTabView()
                        .transition(.opacity)
                        .environmentObject(authManager)
                } else {
                    // 未认证或需要设置密码 → 认证页面
                    AuthView()
                        .transition(.opacity)
                        .environmentObject(authManager)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }
}

#Preview {
    RootView()
}
