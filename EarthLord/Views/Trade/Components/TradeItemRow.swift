//
//  TradeItemRow.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  交易物品行组件 - 显示物品信息
//

import SwiftUI

/// 交易物品行组件
/// 用于在交易相关页面显示物品信息
struct TradeItemRow: View {
    let itemId: String
    let quantity: Int
    var showStock: Bool = false
    var stockQuantity: Int = 0
    var compact: Bool = false

    /// 物品定义（从物品池获取）
    private var itemDefinition: RewardItemDefinition? {
        let allItems = RewardGenerator.commonItems + RewardGenerator.rareItems + RewardGenerator.epicItems
        return allItems.first { $0.id == itemId }
    }

    /// 物品名称
    private var itemName: String {
        itemDefinition?.name ?? itemId
    }

    /// 物品图标
    private var itemIcon: String {
        itemDefinition?.icon ?? "cube.fill"
    }

    /// 物品稀有度
    private var itemRarity: ItemRarity {
        itemDefinition?.rarity ?? .common
    }

    /// 是否库存充足
    private var isSufficient: Bool {
        !showStock || stockQuantity >= quantity
    }

    var body: some View {
        if compact {
            compactView
        } else {
            fullView
        }
    }

    // MARK: - 完整视图

    private var fullView: some View {
        HStack(spacing: 12) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(itemRarity.color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: itemIcon)
                    .font(.system(size: 18))
                    .foregroundColor(itemRarity.color)
            }

            // 物品信息
            VStack(alignment: .leading, spacing: 4) {
                Text(itemName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)

                Text(itemRarity.rawValue)
                    .font(.system(size: 11))
                    .foregroundColor(itemRarity.color)
            }

            Spacer()

            // 数量显示
            if showStock {
                // 显示库存状态
                HStack(spacing: 4) {
                    Text("\(stockQuantity)")
                        .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
                    Text("/")
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(quantity)")
                        .foregroundColor(.white.opacity(0.7))
                }
                .font(.system(size: 14, weight: .medium))

                Image(systemName: isSufficient ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
            } else {
                Text("x\(quantity)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - 紧凑视图

    private var compactView: some View {
        HStack(spacing: 6) {
            // 小图标
            ZStack {
                Circle()
                    .fill(itemRarity.color.opacity(0.2))
                    .frame(width: 28, height: 28)

                Image(systemName: itemIcon)
                    .font(.system(size: 12))
                    .foregroundColor(itemRarity.color)
            }

            // 名称和数量
            VStack(alignment: .leading, spacing: 2) {
                Text(itemName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("x\(quantity)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(itemRarity.color)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 16) {
        TradeItemRow(itemId: "water_bottle", quantity: 3)
        TradeItemRow(itemId: "first_aid_kit", quantity: 1)
        TradeItemRow(itemId: "antibiotic", quantity: 2, showStock: true, stockQuantity: 1)
        TradeItemRow(itemId: "wood", quantity: 5, showStock: true, stockQuantity: 10)

        HStack {
            TradeItemRow(itemId: "water_bottle", quantity: 2, compact: true)
            TradeItemRow(itemId: "bandage", quantity: 3, compact: true)
        }
    }
    .padding()
    .background(ApocalypseTheme.background)
}
