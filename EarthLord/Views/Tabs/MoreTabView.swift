//
//  MoreTabView.swift
//  EarthLord
//
//  Created by yanshuang ren on 2026/1/4.
//

import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("开发工具") {
                    NavigationLink(destination: SupabaseTestView()) {
                        HStack {
                            Image(systemName: "network")
                                .foregroundColor(.blue)
                            Text("Supabase 连接测试")
                        }
                    }
                }

                Section("更多功能") {
                    HStack {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.gray)
                        Text("功能开发中...")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("更多")
        }
    }
}

#Preview {
    MoreTabView()
}
