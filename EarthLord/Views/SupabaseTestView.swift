//
//  SupabaseTestView.swift
//  EarthLord
//
//  Created by yanshuang ren on 2026/1/5.
//

import SwiftUI
import Supabase

// 在 View 外部初始化 Supabase 客户端
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://fbisbjxlwucmxgunkcxh.supabase.co")!,
    supabaseKey: "sb_publishable_NwkBsPp_auo1oeV_E-ENWg_8BQw_PNi"
)

struct SupabaseTestView: View {
    @State private var isConnected: Bool? = nil
    @State private var debugLog: String = "点击按钮开始测试..."
    @State private var isTesting: Bool = false

    var body: some View {
        VStack(spacing: 30) {
            // 标题
            Text("Supabase 连接测试")
                .font(.title)
                .fontWeight(.bold)

            // 状态图标
            Group {
                if let connected = isConnected {
                    if connected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.red)
                    }
                } else {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 80))
                        .foregroundColor(.gray)
                }
            }
            .animation(.easeInOut, value: isConnected)

            // 调试日志文本框
            ScrollView {
                Text(debugLog)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(height: 200)
            .padding(.horizontal)

            // 测试按钮
            Button(action: testConnection) {
                HStack {
                    if isTesting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(isTesting ? "测试中..." : "测试连接")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isTesting ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isTesting)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 40)
    }

    // 测试连接函数
    func testConnection() {
        isTesting = true
        debugLog = "正在测试连接...\n"

        Task {
            do {
                // 故意查询一个不存在的表来测试连接
                debugLog += "发送请求: 查询 non_existent_table...\n"
                let _: [String] = try await supabase
                    .from("non_existent_table")
                    .select()
                    .execute()
                    .value

                // 如果没有报错（理论上不会到这里）
                await MainActor.run {
                    isConnected = true
                    debugLog += "\n✅ 连接成功（意外获得响应）"
                    isTesting = false
                }

            } catch {
                // 分析错误类型
                let errorMessage = error.localizedDescription
                debugLog += "收到错误: \(errorMessage)\n\n"

                await MainActor.run {
                    // 判断错误类型
                    if errorMessage.contains("PGRST") ||
                       errorMessage.contains("PGRST205") ||
                       errorMessage.contains("Could not find the table") ||
                       errorMessage.contains("relation") && errorMessage.contains("does not exist") {
                        // 这些错误说明服务器已响应，连接成功
                        isConnected = true
                        debugLog += "✅ 连接成功（服务器已响应）\n"
                        debugLog += "说明：收到预期的表不存在错误，证明已成功连接到 Supabase 服务器"
                    } else if errorMessage.contains("hostname") ||
                              errorMessage.contains("URL") ||
                              errorMessage.contains("NSURLErrorDomain") {
                        // URL 或网络错误
                        isConnected = false
                        debugLog += "❌ 连接失败：URL 错误或无网络\n"
                        debugLog += "详细信息: \(errorMessage)"
                    } else {
                        // 其他错误
                        isConnected = false
                        debugLog += "❌ 未知错误\n"
                        debugLog += "详细信息: \(errorMessage)"
                    }

                    isTesting = false
                }
            }
        }
    }
}

#Preview {
    SupabaseTestView()
}
