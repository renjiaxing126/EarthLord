//
//  MoreTabView.swift
//  EarthLord
//
//  Created by yanshuang ren on 2026/1/4.
//

import SwiftUI

struct MoreTabView: View {
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        NavigationStack {
            List {
                Section("开发工具".appLocalized) {
                    NavigationLink(destination: TestMenuView()) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(.blue)
                            LocalizedText(key: "开发测试")
                        }
                    }
                }

                Section("更多功能".appLocalized) {
                    HStack {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.gray)
                        LocalizedText(key: "功能开发中...")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("更多".appLocalized)
        }
    }
}

#Preview {
    MoreTabView()
}
