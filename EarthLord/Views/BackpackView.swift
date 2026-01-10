//
//  BackpackView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/9.
//  玩家的背包管理页面
//

import SwiftUI

struct BackpackView: View {
    // MARK: - State

    /// 搜索文字
    @State private var searchText = ""

    /// 当前选中的筛选类型（nil 表示全部）
    @State private var selectedFilter: ItemType? = nil

    /// 背包容量
    private let maxCapacity: Double = 100.0
    private var currentCapacity: Double {
        MockExplorationData.calculateTotalWeight(items: allItems)
    }

    /// 容量百分比
    private var capacityPercentage: Double {
        currentCapacity / maxCapacity
    }

    /// 容量进度条颜色
    private var capacityColor: Color {
        if capacityPercentage < 0.7 {
            return ApocalypseTheme.success
        } else if capacityPercentage < 0.9 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.danger
        }
    }

    /// 是否显示容量警告
    private var showCapacityWarning: Bool {
        capacityPercentage > 0.9
    }

    /// 所有物品
    private var allItems: [BackpackItem] {
        MockExplorationData.mockBackpackItems
    }

    /// 根据搜索和筛选条件过滤后的物品
    private var filteredItems: [BackpackItem] {
        var items = allItems

        // 按类型筛选
        if let filter = selectedFilter {
            items = items.filter { $0.type == filter }
        }

        // 按名称搜索
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return items
    }

    /// 空状态图标
    private var emptyStateIcon: String {
        if allItems.isEmpty {
            return "backpack"
        } else if !searchText.isEmpty {
            return "magnifyingglass"
        } else {
            return "tray"
        }
    }

    /// 空状态标题
    private var emptyStateTitle: String {
        if allItems.isEmpty {
            return "背包空空如也"
        } else if !searchText.isEmpty {
            return "没有找到相关物品"
        } else {
            return "该分类下暂无物品"
        }
    }

    /// 空状态消息
    private var emptyStateMessage: String {
        if allItems.isEmpty {
            return "去探索收集物资吧"
        } else if !searchText.isEmpty {
            return "试试搜索其他关键词"
        } else {
            return "试试其他分类"
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 容量状态卡
                capacityCard
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // 搜索框
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                // 筛选工具栏
                filterToolbar
                    .padding(.vertical, 8)

                // 物品列表或空状态
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    itemList
                }
            }
        }
        .navigationTitle("背包")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 子视图

    /// 容量状态卡
    private var capacityCard: some View {
        VStack(spacing: 12) {
            // 容量文字
            HStack {
                Text("背包容量：")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("\(Int(currentCapacity)) / \(Int(maxCapacity))")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(capacityColor)

                Spacer()

                Text("\(Int(capacityPercentage * 100))%")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(capacityColor)
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ApocalypseTheme.cardBackground)
                        .frame(height: 12)

                    // 进度
                    RoundedRectangle(cornerRadius: 8)
                        .fill(capacityColor)
                        .frame(width: geometry.size.width * capacityPercentage, height: 12)
                        .animation(.easeInOut, value: capacityPercentage)
                }
            }
            .frame(height: 12)

            // 警告文字
            if showCapacityWarning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.danger)

                    Text("背包快满了！")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.danger)

                    Spacer()
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 搜索框
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("搜索物品名称", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .tint(ApocalypseTheme.primary)

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 筛选工具栏
    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 全部按钮
                filterButton(title: "全部", type: nil, icon: "square.grid.2x2.fill")

                // 各类型按钮
                ForEach(ItemType.allCases, id: \.self) { type in
                    filterButton(title: type.rawValue, type: type, icon: type.icon)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// 筛选按钮
    private func filterButton(title: String, type: ItemType?, icon: String) -> some View {
        let isSelected = selectedFilter == type

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = type
            }
        }) {
            HStack(spacing: 6) {
                // 图标
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : (type?.color ?? ApocalypseTheme.textPrimary))

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : ApocalypseTheme.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isSelected ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
    }

    /// 物品列表
    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredItems) { item in
                    itemCard(item: item)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .animation(.easeInOut(duration: 0.3), value: selectedFilter)
        }
    }

    /// 物品卡片
    private func itemCard(item: BackpackItem) -> some View {
        HStack(spacing: 12) {
            // 左边：圆形图标
            ZStack {
                Circle()
                    .fill(item.type.color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(item.type.color)
            }

            // 中间：物品信息
            VStack(alignment: .leading, spacing: 4) {
                // 名称
                Text(item.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 数量 + 重量
                HStack(spacing: 8) {
                    Text("x\(item.quantity)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("•")
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text("\(String(format: "%.1f", item.weight))kg")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 品质标签（如果有）
                if let quality = item.quality {
                    qualityBadge(quality: quality)
                }
            }

            Spacer()

            // 右边：操作按钮
            VStack(spacing: 6) {
                actionButton(title: "使用", icon: "hand.raised.fill") {
                    print("使用物品：\(item.name)")
                }

                actionButton(title: "存储", icon: "arrow.down.doc.fill") {
                    print("存储物品：\(item.name)")
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(item.type.color.opacity(0.3), lineWidth: 1)
        )
    }

    /// 品质徽章
    private func qualityBadge(quality: ItemQuality) -> some View {
        Text(quality.rawValue)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(quality.color)
            )
    }

    /// 操作按钮
    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ApocalypseTheme.primary)
            )
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.textMuted.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: emptyStateIcon)
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 提示文字
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(emptyStateMessage)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .multilineTextAlignment(.center)
            }

            // 清除筛选按钮
            if !searchText.isEmpty || selectedFilter != nil {
                Button(action: {
                    withAnimation {
                        searchText = ""
                        selectedFilter = nil
                    }
                }) {
                    Text("清除筛选")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(ApocalypseTheme.primary)
                        )
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 预览

#Preview {
    NavigationView {
        BackpackView()
    }
}
