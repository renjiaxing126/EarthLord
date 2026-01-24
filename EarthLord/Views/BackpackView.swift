//
//  BackpackView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/9.
//  玩家的背包管理页面 - 使用真实数据
//

import SwiftUI

/// 背包物品显示模型（组合 InventoryItem 和物品定义）
struct BackpackDisplayItem: Identifiable {
    let id: String
    let itemId: String
    let name: String
    let icon: String
    let quantity: Int
    let rarity: ItemRarity
    let category: String
    let obtainedAt: Date

    /// 从 InventoryItem 和物品定义创建
    init(from inventoryItem: InventoryItem, definition: RewardItemDefinition?) {
        self.id = inventoryItem.id
        self.itemId = inventoryItem.itemId
        self.quantity = inventoryItem.quantity
        self.obtainedAt = inventoryItem.obtainedAt

        if let def = definition {
            self.name = def.name
            self.icon = def.icon
            self.rarity = def.rarity
            self.category = def.category
        } else {
            // 未知物品的默认值
            self.name = inventoryItem.itemId
            self.icon = "questionmark.circle"
            self.rarity = .common
            self.category = "unknown"
        }
    }
}

struct BackpackView: View {
    // MARK: - State

    /// 背包管理器
    @StateObject private var inventoryManager = InventoryManager.shared

    /// 搜索文字
    @State private var searchText = ""

    /// 当前选中的筛选类型（nil 表示全部）
    @State private var selectedCategory: String? = nil

    /// 背包容量（物品种类数上限）
    private let maxCapacity: Int = 100

    /// 容量百分比
    private var capacityPercentage: Double {
        Double(inventoryManager.itemTypeCount) / Double(maxCapacity)
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

    /// 所有分类
    private let categories = ["全部", "food", "medical", "tool", "material"]

    /// 分类显示名称
    private func categoryDisplayName(_ category: String) -> String {
        switch category {
        case "全部": return "全部"
        case "food": return "食物"
        case "medical": return "医疗"
        case "tool": return "工具"
        case "material": return "材料"
        default: return category
        }
    }

    /// 分类图标
    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "全部": return "square.grid.2x2.fill"
        case "food": return "takeoutbag.and.cup.and.straw.fill"
        case "medical": return "cross.case.fill"
        case "tool": return "wrench.and.screwdriver.fill"
        case "material": return "shippingbox.fill"
        default: return "questionmark.circle"
        }
    }

    /// 分类颜色
    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "food": return .orange
        case "medical": return .red
        case "tool": return .blue
        case "material": return .brown
        default: return ApocalypseTheme.textPrimary
        }
    }

    /// 转换后的显示物品列表
    private var displayItems: [BackpackDisplayItem] {
        inventoryManager.items.map { item in
            let definition = inventoryManager.getItemDefinition(itemId: item.itemId)
            return BackpackDisplayItem(from: item, definition: definition)
        }
    }

    /// 根据搜索和筛选条件过滤后的物品
    private var filteredItems: [BackpackDisplayItem] {
        var items = displayItems

        // 按类型筛选
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }

        // 按名称搜索
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return items
    }

    /// 空状态图标
    private var emptyStateIcon: String {
        if displayItems.isEmpty {
            return "backpack"
        } else if !searchText.isEmpty {
            return "magnifyingglass"
        } else {
            return "tray"
        }
    }

    /// 空状态标题
    private var emptyStateTitle: String {
        if displayItems.isEmpty {
            return "背包空空如也"
        } else if !searchText.isEmpty {
            return "没有找到相关物品"
        } else {
            return "该分类下暂无物品"
        }
    }

    /// 空状态消息
    private var emptyStateMessage: String {
        if displayItems.isEmpty {
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

            if inventoryManager.isLoading {
                // 加载状态
                loadingView
            } else {
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
        }
        .navigationTitle("背包")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("🎒 [BackpackView] 页面出现，加载背包数据")
            Task {
                await inventoryManager.loadInventory()
            }
        }
        .refreshable {
            print("🔄 [BackpackView] 下拉刷新")
            await inventoryManager.loadInventory()
        }
    }

    // MARK: - 子视图

    /// 加载视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.5)

            Text("加载背包中...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    /// 容量状态卡
    private var capacityCard: some View {
        VStack(spacing: 12) {
            // 容量文字
            HStack {
                Text("背包容量：")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("\(inventoryManager.itemTypeCount) / \(maxCapacity) 种")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(capacityColor)

                Spacer()

                Text("共 \(inventoryManager.totalItemCount) 件")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)
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
                ForEach(categories, id: \.self) { category in
                    let actualCategory = category == "全部" ? nil : category
                    filterButton(
                        title: categoryDisplayName(category),
                        category: actualCategory,
                        icon: categoryIcon(category),
                        color: categoryColor(category)
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// 筛选按钮
    private func filterButton(title: String, category: String?, icon: String, color: Color) -> some View {
        let isSelected = selectedCategory == category

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        }) {
            HStack(spacing: 6) {
                // 图标
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : color)

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
            .animation(.easeInOut(duration: 0.3), value: selectedCategory)
        }
    }

    /// 物品卡片
    private func itemCard(item: BackpackDisplayItem) -> some View {
        HStack(spacing: 12) {
            // 左边：圆形图标
            ZStack {
                Circle()
                    .fill(categoryColor(item.category).opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(categoryColor(item.category))
            }

            // 中间：物品信息
            VStack(alignment: .leading, spacing: 4) {
                // 名称
                Text(item.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 数量
                HStack(spacing: 8) {
                    Text("x\(item.quantity)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("•")
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(categoryDisplayName(item.category))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 品质标签
                rarityBadge(rarity: item.rarity)
            }

            Spacer()

            // 右边：操作按钮
            VStack(spacing: 6) {
                actionButton(title: "使用", icon: "hand.raised.fill") {
                    print("🎮 [BackpackView] 使用物品：\(item.name)")
                    // TODO: 实现使用物品逻辑
                }

                actionButton(title: "丢弃", icon: "trash.fill") {
                    print("🗑️ [BackpackView] 丢弃物品：\(item.name)")
                    Task {
                        await inventoryManager.removeItem(itemId: item.itemId, quantity: 1)
                    }
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
                .strokeBorder(item.rarity.color.opacity(0.3), lineWidth: 1)
        )
    }

    /// 品质徽章
    private func rarityBadge(rarity: ItemRarity) -> some View {
        Text(rarity.rawValue)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(rarity.color)
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
                    .fill(title == "丢弃" ? ApocalypseTheme.danger : ApocalypseTheme.primary)
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
            if !searchText.isEmpty || selectedCategory != nil {
                Button(action: {
                    withAnimation {
                        searchText = ""
                        selectedCategory = nil
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
