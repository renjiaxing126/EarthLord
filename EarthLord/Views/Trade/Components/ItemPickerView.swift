//
//  ItemPickerView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  物品选择器弹窗
//

import SwiftUI

/// 物品来源类型
enum ItemSourceType {
    case inventory  // 从背包选择（我要出的物品）
    case allItems   // 从全物品池选择（我想要的物品）
}

/// 可选择的物品
struct SelectableItem: Identifiable {
    let id: String
    let itemId: String
    let name: String
    let icon: String
    let rarity: ItemRarity
    let category: String
    let maxQuantity: Int  // 最大可选数量（背包为库存，全物品池为99）
}

/// 物品分类
enum ItemCategory: String, CaseIterable {
    case all = "全部"
    case food = "食物"
    case water = "水源"
    case medical = "医疗"
    case material = "材料"
    case tool = "工具"

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .food: return "fork.knife"
        case .water: return "drop.fill"
        case .medical: return "cross.case.fill"
        case .material: return "cube.fill"
        case .tool: return "wrench.and.screwdriver.fill"
        }
    }
}

/// 物品选择器视图
struct ItemPickerView: View {
    let title: String
    let sourceType: ItemSourceType
    @Binding var selectedItems: [TradeItem]
    @Environment(\.dismiss) private var dismiss

    @StateObject private var inventoryManager = InventoryManager.shared

    @State private var searchText = ""
    @State private var selectedCategory: ItemCategory = .all
    @State private var tempSelection: [String: Int] = [:]  // itemId -> quantity

    /// 可用物品列表
    private var availableItems: [SelectableItem] {
        switch sourceType {
        case .inventory:
            return inventoryManager.items.map { item in
                let definition = getItemDefinition(item.itemId)
                return SelectableItem(
                    id: item.id,
                    itemId: item.itemId,
                    name: definition?.name ?? item.itemId,
                    icon: definition?.icon ?? "cube.fill",
                    rarity: definition?.rarity ?? .common,
                    category: definition?.category ?? "other",
                    maxQuantity: item.quantity
                )
            }
        case .allItems:
            let allDefinitions = RewardGenerator.commonItems + RewardGenerator.rareItems + RewardGenerator.epicItems
            return allDefinitions.map { item in
                SelectableItem(
                    id: item.id,
                    itemId: item.id,
                    name: item.name,
                    icon: item.icon,
                    rarity: item.rarity,
                    category: item.category,
                    maxQuantity: 99
                )
            }
        }
    }

    /// 过滤后的物品列表
    private var filteredItems: [SelectableItem] {
        var items = availableItems

        // 按分类过滤
        if selectedCategory != .all {
            items = items.filter { matchesCategory($0.category, selectedCategory) }
        }

        // 按搜索词过滤
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return items
    }

    /// 已选物品数量
    private var selectedCount: Int {
        tempSelection.values.reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // 分类选择
                categoryFilter
                    .padding(.top, 12)

                // 物品网格
                itemsGrid
                    .padding(.top, 12)

                // 已选预览
                if selectedCount > 0 {
                    selectedPreview
                }
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        confirmSelection()
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                    .fontWeight(.semibold)
                    .disabled(selectedCount == 0)
                }
            }
            .onAppear {
                // 初始化临时选择
                for item in selectedItems {
                    tempSelection[item.itemId] = item.quantity
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("搜索物品...", text: $searchText)
                .font(.system(size: 14))
                .foregroundColor(.white)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - 分类筛选

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ItemCategory.allCases, id: \.self) { category in
                    categoryChip(category)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func categoryChip(_ category: ItemCategory) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.system(size: 12))
                Text(category.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? ApocalypseTheme.primary : Color.white.opacity(0.05))
            )
        }
    }

    // MARK: - 物品网格

    private var itemsGrid: some View {
        ScrollView {
            if filteredItems.isEmpty {
                emptyResultView
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(filteredItems) { item in
                        itemCell(item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, selectedCount > 0 ? 100 : 20)
            }
        }
    }

    private var emptyResultView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("没有找到物品")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func itemCell(_ item: SelectableItem) -> some View {
        let selectedQty = tempSelection[item.itemId] ?? 0
        let isSelected = selectedQty > 0

        return VStack(spacing: 8) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(item.rarity.color.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: item.icon)
                    .font(.system(size: 22))
                    .foregroundColor(item.rarity.color)

                // 选中标记
                if isSelected {
                    Circle()
                        .fill(ApocalypseTheme.primary)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text("\(selectedQty)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 18, y: -18)
                }
            }

            // 物品名称
            Text(item.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)

            // 稀有度/库存
            HStack(spacing: 4) {
                Circle()
                    .fill(item.rarity.color)
                    .frame(width: 6, height: 6)
                Text(item.rarity.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(item.rarity.color)

                if sourceType == .inventory {
                    Text("• 库存\(item.maxQuantity)")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            // 数量调整
            HStack(spacing: 12) {
                Button {
                    decreaseQuantity(item)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? ApocalypseTheme.danger : .gray.opacity(0.3))
                }
                .disabled(!isSelected)

                Text("\(selectedQty)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 30)

                Button {
                    increaseQuantity(item)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(selectedQty < item.maxQuantity ? ApocalypseTheme.success : .gray.opacity(0.3))
                }
                .disabled(selectedQty >= item.maxQuantity)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? ApocalypseTheme.primary.opacity(0.1) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? ApocalypseTheme.primary.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - 已选预览

    private var selectedPreview: some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.white.opacity(0.1))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(tempSelection.keys.sorted()), id: \.self) { itemId in
                        if let qty = tempSelection[itemId], qty > 0 {
                            selectedItemChip(itemId: itemId, quantity: qty)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 44)
        }
        .padding(.vertical, 8)
        .background(ApocalypseTheme.cardBackground)
    }

    private func selectedItemChip(itemId: String, quantity: Int) -> some View {
        let definition = getItemDefinition(itemId)

        return HStack(spacing: 6) {
            Image(systemName: definition?.icon ?? "cube.fill")
                .font(.system(size: 12))
                .foregroundColor(definition?.rarity.color ?? .gray)

            Text(definition?.name ?? itemId)
                .font(.system(size: 12))
                .foregroundColor(.white)

            Text("x\(quantity)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(ApocalypseTheme.primary)

            Button {
                tempSelection[itemId] = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.1))
        )
    }

    // MARK: - Helper Methods

    private func getItemDefinition(_ itemId: String) -> RewardItemDefinition? {
        let allItems = RewardGenerator.commonItems + RewardGenerator.rareItems + RewardGenerator.epicItems
        return allItems.first { $0.id == itemId }
    }

    private func matchesCategory(_ itemCategory: String, _ filter: ItemCategory) -> Bool {
        switch filter {
        case .all: return true
        case .food: return itemCategory == "food"
        case .water: return itemCategory == "water"
        case .medical: return itemCategory == "medical"
        case .material: return itemCategory == "material"
        case .tool: return itemCategory == "tool"
        }
    }

    private func increaseQuantity(_ item: SelectableItem) {
        let current = tempSelection[item.itemId] ?? 0
        if current < item.maxQuantity {
            tempSelection[item.itemId] = current + 1
        }
    }

    private func decreaseQuantity(_ item: SelectableItem) {
        let current = tempSelection[item.itemId] ?? 0
        if current > 1 {
            tempSelection[item.itemId] = current - 1
        } else {
            tempSelection[item.itemId] = nil
        }
    }

    private func confirmSelection() {
        selectedItems = tempSelection.compactMap { itemId, quantity in
            guard quantity > 0 else { return nil }
            return TradeItem(itemId: itemId, quantity: quantity)
        }
    }
}

// MARK: - 预览

#Preview {
    struct PreviewWrapper: View {
        @State var items: [TradeItem] = []

        var body: some View {
            ItemPickerView(
                title: "选择物品",
                sourceType: .allItems,
                selectedItems: $items
            )
        }
    }

    return PreviewWrapper()
}
