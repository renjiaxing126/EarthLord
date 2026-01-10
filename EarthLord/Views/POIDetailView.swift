//
//  POIDetailView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/10.
//  POI 详情页面
//

import SwiftUI

/// POI 危险等级
enum POIDangerLevel: String {
    case safe = "安全"
    case low = "低危"
    case medium = "中危"
    case high = "高危"

    /// 颜色
    var color: Color {
        switch self {
        case .safe:
            return ApocalypseTheme.success
        case .low:
            return ApocalypseTheme.info
        case .medium:
            return ApocalypseTheme.warning
        case .high:
            return ApocalypseTheme.danger
        }
    }

    /// 图标
    var icon: String {
        switch self {
        case .safe:
            return "checkmark.shield.fill"
        case .low:
            return "exclamationmark.shield.fill"
        case .medium:
            return "exclamationmark.triangle.fill"
        case .high:
            return "xmark.shield.fill"
        }
    }
}

/// POI 来源
enum POISource: String {
    case mapData = "地图数据"
    case manual = "手动添加"

    var icon: String {
        switch self {
        case .mapData:
            return "map.fill"
        case .manual:
            return "hand.raised.fill"
        }
    }
}

struct POIDetailView: View {
    // MARK: - Properties

    let poi: POI

    // MARK: - State

    /// 是否正在搜寻
    @State private var isSearching = false

    /// 是否显示探索结果
    @State private var showExplorationResult = false

    /// 危险等级（假数据，实际应该从POI获取）
    private var dangerLevel: POIDangerLevel {
        // 根据POI类型返回不同的危险等级
        switch poi.type {
        case .hospital:
            return .medium
        case .supermarket:
            return .low
        case .factory:
            return .high
        case .pharmacy:
            return .low
        case .gasStation:
            return .medium
        }
    }

    /// 来源（假数据）
    private var source: POISource {
        return .mapData
    }

    /// 距离（使用POI中的距离或假数据）
    private var distance: Double {
        return poi.distanceFromUser ?? 350.0
    }

    /// 是否可以搜寻
    private var canSearch: Bool {
        return poi.status != .depleted
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 顶部大图区域
                    headerSection

                    // 内容区域
                    VStack(spacing: 20) {
                        // 信息卡片
                        infoCard

                        // 描述卡片
                        if !poi.description.isEmpty {
                            descriptionCard
                        }

                        // 操作按钮区域
                        actionButtons
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExplorationResult) {
            ExplorationResultView(
                stats: MockExplorationData.mockExplorationResult.stats,
                reward: MockExplorationData.mockExplorationResult.reward
            )
        }
    }

    // MARK: - 子视图

    /// 顶部大图区域
    private var headerSection: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 渐变背景
                LinearGradient(
                    colors: [
                        poi.type.color.opacity(0.8),
                        poi.type.color.opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // 装饰圆圈
                Circle()
                    .fill(poi.type.color.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .offset(x: -50, y: -50)
                    .blur(radius: 30)

                Circle()
                    .fill(poi.type.color.opacity(0.15))
                    .frame(width: 150, height: 150)
                    .offset(x: geometry.size.width - 100, y: 20)
                    .blur(radius: 20)

                // 中间大图标
                VStack(spacing: 16) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 120, height: 120)

                        Image(systemName: poi.type.icon)
                            .font(.system(size: 80, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)

                // 底部半透明遮罩
                VStack(spacing: 8) {
                    // POI 名称
                    Text(poi.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    // POI 类型
                    HStack(spacing: 8) {
                        Image(systemName: poi.type.icon)
                            .font(.system(size: 14, weight: .semibold))

                        Text(poi.type.rawValue)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.2))
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(0.6),
                            .black.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .frame(height: UIScreen.main.bounds.height / 3)
    }

    /// 信息卡片
    private var infoCard: some View {
        VStack(spacing: 16) {
            // 距离
            infoRow(
                icon: "location.fill",
                title: "距离",
                value: String(format: "%.0f米", distance),
                color: ApocalypseTheme.primary
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 物资状态
            infoRow(
                icon: poi.hasResources ? "checkmark.circle.fill" : "xmark.circle.fill",
                title: "物资状态",
                value: poi.hasResources ? "有物资" : "已清空",
                color: poi.hasResources ? ApocalypseTheme.success : ApocalypseTheme.danger
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 危险等级
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: dangerLevel.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(dangerLevel.color)

                    Text("危险等级")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                Text(dangerLevel.rawValue)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(dangerLevel.color)
                    )
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 来源
            infoRow(
                icon: source.icon,
                title: "来源",
                value: source.rawValue,
                color: ApocalypseTheme.info
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 发现状态
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(statusColor(for: poi.status))

                    Text("发现状态")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                Text(statusText(for: poi.status))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(statusColor(for: poi.status))
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 描述卡片
    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("地点描述")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Text(poi.description)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 操作按钮区域
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // 主按钮 - 搜寻此POI
            searchButton

            // 标记按钮组
            HStack(spacing: 12) {
                // 标记已发现
                markButton(
                    title: "标记已发现",
                    icon: "eye.fill",
                    color: ApocalypseTheme.info
                ) {
                    print("标记已发现")
                }

                // 标记无物资
                markButton(
                    title: "标记无物资",
                    icon: "xmark.circle.fill",
                    color: ApocalypseTheme.warning
                ) {
                    print("标记无物资")
                }
            }
        }
    }

    /// 搜寻按钮
    private var searchButton: some View {
        Button(action: {
            if canSearch {
                performSearch()
            }
        }) {
            HStack(spacing: 12) {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)

                    Text("搜寻中...")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: canSearch ? "magnifyingglass.circle.fill" : "lock.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Text(canSearch ? "搜寻此POI" : "已被搜空")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        canSearch ?
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.textMuted,
                                ApocalypseTheme.textMuted
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(
                color: canSearch ? ApocalypseTheme.primary.opacity(0.3) : .clear,
                radius: 12,
                x: 0,
                y: 4
            )
        }
        .disabled(!canSearch || isSearching)
        .opacity(canSearch ? 1.0 : 0.6)
    }

    /// 标记按钮
    private func markButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
            )
        }
    }

    /// 信息行
    private func infoRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    // MARK: - 辅助方法

    /// 获取状态文本
    private func statusText(for status: POIStatus) -> String {
        switch status {
        case .undiscovered:
            return "未发现"
        case .discovered:
            return "已发现"
        case .depleted:
            return "已搜空"
        }
    }

    /// 获取状态颜色
    private func statusColor(for status: POIStatus) -> Color {
        switch status {
        case .undiscovered:
            return ApocalypseTheme.textMuted
        case .discovered:
            return ApocalypseTheme.info
        case .depleted:
            return ApocalypseTheme.danger
        }
    }

    /// 执行搜寻（模拟）
    private func performSearch() {
        isSearching = true

        // 2秒后完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                isSearching = false
            }
            // 显示探索结果弹窗
            showExplorationResult = true
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationView {
        POIDetailView(poi: MockExplorationData.mockPOIs[0])
    }
}

#Preview("已搜空POI") {
    NavigationView {
        POIDetailView(poi: MockExplorationData.mockPOIs[1])
    }
}
