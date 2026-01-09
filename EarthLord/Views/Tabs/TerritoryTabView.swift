//
//  TerritoryTabView.swift
//  EarthLord
//
//  Created by yanshuang ren on 2026/1/4.
//

import SwiftUI

// MARK: - 通知名称扩展
extension Notification.Name {
    /// 领地数据更新通知（上传/删除后发送）
    static let territoryUpdated = Notification.Name("territoryUpdated")

    /// Day 19: 触发碰撞检测通知（定时器触发）
    static let triggerCollisionCheck = Notification.Name("triggerCollisionCheck")
}

struct TerritoryTabView: View {
    @State private var myTerritories: [Territory] = []
    @State private var selectedTerritory: Territory?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    private let territoryManager = TerritoryManager.shared

    /// 监听领地更新通知
    private let territoryUpdatedPublisher = NotificationCenter.default.publisher(for: .territoryUpdated)

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                ApocalypseTheme.background.ignoresSafeArea()

                if isLoading && myTerritories.isEmpty {
                    // 加载中
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(ApocalypseTheme.primary)
                } else if myTerritories.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 领地列表
                    ScrollView {
                        VStack(spacing: 16) {
                            // 统计头部
                            statisticsHeader

                            // 领地卡片列表
                            ForEach(myTerritories) { territory in
                                TerritoryCard(territory: territory)
                                    .onTapGesture {
                                        selectedTerritory = territory
                                    }
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await loadMyTerritories()
                    }
                }
            }
            .navigationTitle("我的领地")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task {
                    await loadMyTerritories()
                }
            }
            .onReceive(territoryUpdatedPublisher) { _ in
                // 收到领地更新通知，刷新列表
                Task {
                    await loadMyTerritories()
                }
            }
            .sheet(item: $selectedTerritory) { territory in
                TerritoryDetailView(territory: territory) {
                    // 删除回调
                    Task {
                        await loadMyTerritories()
                    }
                }
            }
            .alert("加载失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - 统计头部

    private var statisticsHeader: some View {
        HStack(spacing: 20) {
            // 领地数量
            StatisticCard(
                icon: "flag.fill",
                title: "领地数量",
                value: "\(myTerritories.count)",
                color: ApocalypseTheme.primary
            )

            // 总面积
            StatisticCard(
                icon: "map.fill",
                title: "总面积",
                value: formattedTotalArea,
                color: .green
            )
        }
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "flag.slash.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 文字
            VStack(spacing: 12) {
                Text("暂无领地")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("前往地图开始圈地吧！")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - 计算属性

    private var formattedTotalArea: String {
        let totalArea = myTerritories.reduce(0) { $0 + $1.area }
        if totalArea >= 1_000_000 {
            return String(format: "%.2f km²", totalArea / 1_000_000)
        } else {
            return String(format: "%.0f m²", totalArea)
        }
    }

    // MARK: - 方法

    private func loadMyTerritories() async {
        isLoading = true
        do {
            myTerritories = try await territoryManager.loadMyTerritories()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
}

// MARK: - 统计卡片

struct StatisticCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))

                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - 领地卡片

struct TerritoryCard: View {
    let territory: Territory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundColor(ApocalypseTheme.primary)

                Text(territory.displayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }

            // 信息行
            HStack(spacing: 16) {
                // 面积
                InfoItem(icon: "map.fill", text: territory.formattedArea)

                // 点数
                if let pointCount = territory.pointCount {
                    InfoItem(icon: "mappin.circle.fill", text: "\(pointCount) 点")
                }

                Spacer()
            }

            // 时间
            if let createdAt = territory.createdAt {
                Text(formatDate(createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return displayFormatter.string(from: date)
    }
}

// MARK: - 信息项

struct InfoItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

#Preview {
    TerritoryTabView()
}
