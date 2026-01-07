//
//  TerritoryTestView.swift
//  EarthLord
//
//  Created by Claude Code on 2026/1/7.
//

import SwiftUI

/// 圈地功能测试界面
/// ⚠️ 注意：此视图不套 NavigationStack，因为它是从 TestMenuView 导航进来的
struct TerritoryTestView: View {
    // MARK: - Dependencies

    /// 位置管理器（监听追踪状态）
    @EnvironmentObject var locationManager: LocationManager

    /// 日志管理器（监听日志更新）
    @ObservedObject var logger = TerritoryLogger.shared

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 状态指示器
            statusIndicator
                .padding()
                .background(Color(red: 0.15, green: 0.15, blue: 0.15))

            Divider()
                .background(Color.white.opacity(0.2))

            // 日志滚动区域
            logScrollView

            Divider()
                .background(Color.white.opacity(0.2))

            // 底部按钮
            bottomButtons
                .padding()
                .background(Color(red: 0.15, green: 0.15, blue: 0.15))
        }
        .navigationTitle("圈地测试")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black)
    }

    // MARK: - Components

    /// 状态指示器
    private var statusIndicator: some View {
        HStack(spacing: 12) {
            // 状态点
            Circle()
                .fill(locationManager.isTracking ? Color.green : Color.gray)
                .frame(width: 12, height: 12)

            // 状态文字
            Text(locationManager.isTracking ? "追踪中" : "未追踪")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(locationManager.isTracking ? .green : .gray)

            // 路径点数
            if locationManager.isTracking {
                Text("·")
                    .foregroundColor(.gray)

                Text("\(locationManager.pathCoordinates.count) 个点")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
    }

    /// 日志滚动区域
    private var logScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if logger.logText.isEmpty {
                        // 空状态提示
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)

                            Text("暂无日志")
                                .font(.system(size: 17))
                                .foregroundColor(.gray)

                            Text("开始圈地追踪后，日志将显示在这里")
                                .font(.system(size: 14))
                                .foregroundColor(.gray.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        // 日志文本
                        Text(logger.logText)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("logText") // 用于自动滚动
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .onChange(of: logger.logText) {
                // 日志更新时自动滚动到底部
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("logText", anchor: .bottom)
                }
            }
        }
    }

    /// 底部按钮
    private var bottomButtons: some View {
        HStack(spacing: 16) {
            // 清空日志按钮
            Button {
                logger.clear()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    Text("清空日志")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.8))
                )
            }
            .disabled(logger.logs.isEmpty)
            .opacity(logger.logs.isEmpty ? 0.5 : 1.0)

            // 导出日志按钮
            ShareLink(item: logger.export()) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出日志")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ApocalypseTheme.primary)
                )
            }
            .disabled(logger.logs.isEmpty)
            .opacity(logger.logs.isEmpty ? 0.5 : 1.0)
        }
    }
}

#Preview {
    NavigationStack {
        TerritoryTestView()
            .environmentObject(LocationManager.shared)
    }
}
