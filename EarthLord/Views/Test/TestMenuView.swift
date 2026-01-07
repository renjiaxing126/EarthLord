//
//  TestMenuView.swift
//  EarthLord
//
//  Created by Claude Code on 2026/1/7.
//

import SwiftUI

/// 开发测试菜单
/// ⚠️ 注意：此视图不套 NavigationStack，因为它已经在 ContentView 的 NavigationStack 内部
struct TestMenuView: View {
    var body: some View {
        List {
            // Supabase 连接测试
            NavigationLink(destination: SupabaseTestView()) {
                HStack(spacing: 16) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 24))
                        .foregroundColor(ApocalypseTheme.primary)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Supabase 连接测试")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)

                        Text("测试数据库连接状态")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.15))

            // 圈地功能测试
            NavigationLink(destination: TerritoryTestView()) {
                HStack(spacing: 16) {
                    Image(systemName: "map.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(ApocalypseTheme.primary)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("圈地功能测试")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)

                        Text("查看实时日志和调试信息")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.15))
        }
        .navigationTitle("开发测试")
        .navigationBarTitleDisplayMode(.large)
        .scrollContentBackground(.hidden)
        .background(Color.black)
    }
}

#Preview {
    NavigationStack {
        TestMenuView()
    }
    .environmentObject(LanguageManager.shared)
}
