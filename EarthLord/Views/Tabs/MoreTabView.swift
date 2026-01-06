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
                Section(String(localized: "开发工具")) {
                    NavigationLink(destination: SupabaseTestView()) {
                        HStack {
                            Image(systemName: "network")
                                .foregroundColor(.blue)
                            Text(String(localized: "Supabase 连接测试"))
                        }
                    }
                }

                Section(String(localized: "更多功能")) {
                    HStack {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.gray)
                        Text(String(localized: "功能开发中..."))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(String(localized: "更多"))
        }
    }
}

#Preview {
    MoreTabView()
}
