//
//  ResourcesTabView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/10.
//  资源模块主入口页面
//

import SwiftUI

/// 资源分段类型
enum ResourceSegment: String, CaseIterable {
    case poi = "POI"
    case backpack = "背包"
    case purchased = "已购"
    case territory = "领地"
    case trade = "交易"
}

struct ResourcesTabView: View {
    // MARK: - State

    /// 当前选中的分段
    @State private var selectedSegment: ResourceSegment = .poi

    /// 交易开关状态（假数据）
    @State private var isTradingEnabled = false

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 顶部交易开关
                    tradingToggle
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(ApocalypseTheme.cardBackground)

                    // 分段选择器
                    segmentPicker
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    // 内容区域
                    contentView
                }
            }
            .navigationTitle("资源")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - 子视图

    /// 交易开关
    private var tradingToggle: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isTradingEnabled ? ApocalypseTheme.success : ApocalypseTheme.textMuted)

                Text("交易功能")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Spacer()

            Toggle("", isOn: $isTradingEnabled)
                .labelsHidden()
                .tint(ApocalypseTheme.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.background)
        )
    }

    /// 分段选择器
    private var segmentPicker: some View {
        Picker("选择分段", selection: $selectedSegment) {
            ForEach(ResourceSegment.allCases, id: \.self) { segment in
                Text(segment.rawValue)
                    .tag(segment)
            }
        }
        .pickerStyle(.segmented)
    }

    /// 内容区域
    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case .poi:
            // POI 列表
            POIListView()

        case .backpack:
            // 背包页面
            BackpackView()

        case .purchased:
            // 已购页面（占位）
            placeholderView(title: "已购物品", icon: "bag.fill")

        case .territory:
            // 领地页面（占位）
            placeholderView(title: "我的领地", icon: "map.fill")

        case .trade:
            // 交易页面
            TradeTabView()
        }
    }

    /// 占位视图
    private func placeholderView(title: String, icon: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: icon)
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 文字
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("功能开发中")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("敬请期待")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ApocalypseTheme.background)
    }
}

// MARK: - 预览

#Preview {
    ResourcesTabView()
}

#Preview("背包分段") {
    ResourcesTabView()
}
