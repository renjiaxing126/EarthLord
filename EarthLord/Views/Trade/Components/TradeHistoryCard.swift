//
//  TradeHistoryCard.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  交易历史卡片组件
//

import SwiftUI

/// 交易历史卡片组件
struct TradeHistoryCard: View {
    let history: TradeHistory
    let currentUserId: UUID
    var onRateTap: (() -> Void)? = nil

    /// 判断当前用户角色
    private var isSeller: Bool {
        history.sellerId == currentUserId
    }

    /// 交易对方名称
    private var counterpartyName: String {
        if isSeller {
            return formatUsername(history.buyerUsername ?? "未知买家")
        } else {
            return formatUsername(history.sellerUsername ?? "未知卖家")
        }
    }

    /// 我获得的物品
    private var receivedItems: [TradeItem] {
        if isSeller {
            return history.itemsExchanged.buyerOffered
        } else {
            return history.itemsExchanged.sellerOffered
        }
    }

    /// 我付出的物品
    private var givenItems: [TradeItem] {
        if isSeller {
            return history.itemsExchanged.sellerOffered
        } else {
            return history.itemsExchanged.buyerOffered
        }
    }

    /// 是否已评价
    private var hasRated: Bool {
        if isSeller {
            return history.sellerRating != nil
        } else {
            return history.buyerRating != nil
        }
    }

    /// 对方的评价
    private var counterpartyRating: Int? {
        if isSeller {
            return history.buyerRating
        } else {
            return history.sellerRating
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：角色标识 + 时间
            HStack {
                roleIndicator
                Spacer()
                timeLabel
            }

            // 交易对方
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                Text("与 \(counterpartyName) 交易")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // 物品交换详情
            HStack(spacing: 12) {
                // 获得的物品
                itemsSection(items: receivedItems, label: "获得", color: ApocalypseTheme.success)

                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))

                // 付出的物品
                itemsSection(items: givenItems, label: "付出", color: ApocalypseTheme.warning)
            }

            // 底部：评价状态/评价按钮
            HStack {
                // 对方评价
                if let rating = counterpartyRating {
                    HStack(spacing: 4) {
                        Text("对方评价:")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                        starRating(rating)
                    }
                }

                Spacer()

                // 评价按钮
                if hasRated {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("已评价")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(ApocalypseTheme.success.opacity(0.7))
                } else {
                    Button {
                        onRateTap?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                            Text("评价")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.warning)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(ApocalypseTheme.warning.opacity(0.2))
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - 角色标识

    private var roleIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: isSeller ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 14))
            Text(isSeller ? "我是卖家" : "我是买家")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(isSeller ? ApocalypseTheme.primary : ApocalypseTheme.info)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill((isSeller ? ApocalypseTheme.primary : ApocalypseTheme.info).opacity(0.2))
        )
    }

    // MARK: - 时间标签

    private var timeLabel: some View {
        Text(formatDate(history.completedAt))
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.5))
    }

    // MARK: - 物品区块

    private func itemsSection(items: [TradeItem], label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(items.prefix(2)) { item in
                    itemRow(item)
                }
                if items.count > 2 {
                    Text("+\(items.count - 2) 更多")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func itemRow(_ item: TradeItem) -> some View {
        let definition = getItemDefinition(item.itemId)

        return HStack(spacing: 4) {
            Image(systemName: definition?.icon ?? "cube.fill")
                .font(.system(size: 10))
                .foregroundColor(definition?.rarity.color ?? .gray)

            Text(definition?.name ?? item.itemId)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)

            Text("x\(item.quantity)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - 星级评价

    private func starRating(_ rating: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: 10))
                    .foregroundColor(star <= rating ? .yellow : .gray.opacity(0.3))
            }
        }
    }

    // MARK: - Helper

    private func getItemDefinition(_ itemId: String) -> RewardItemDefinition? {
        let allItems = RewardGenerator.commonItems + RewardGenerator.rareItems + RewardGenerator.epicItems
        return allItems.first { $0.id == itemId }
    }

    private func formatUsername(_ username: String) -> String {
        if username.contains("@") {
            let parts = username.split(separator: "@")
            if let name = parts.first {
                let nameStr = String(name)
                if nameStr.count > 3 {
                    return String(nameStr.prefix(3)) + "***"
                }
                return nameStr + "***"
            }
        }
        return username
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 预览

#Preview {
    let mockHistory = TradeHistory(
        id: UUID(),
        offerId: UUID(),
        sellerId: UUID(),
        sellerUsername: "seller@test.com",
        buyerId: UUID(),
        buyerUsername: "buyer@test.com",
        itemsExchanged: TradeExchangeInfo(
            sellerOffered: [
                TradeItem(itemId: "water_bottle", quantity: 5),
                TradeItem(itemId: "bandage", quantity: 3)
            ],
            buyerOffered: [
                TradeItem(itemId: "first_aid_kit", quantity: 1)
            ]
        ),
        completedAt: Date(),
        sellerRating: nil,
        buyerRating: 4,
        sellerComment: nil,
        buyerComment: nil
    )

    ScrollView {
        VStack(spacing: 16) {
            // 作为卖家
            TradeHistoryCard(
                history: mockHistory,
                currentUserId: mockHistory.sellerId
            ) {
                print("Rate tapped")
            }

            // 作为买家
            TradeHistoryCard(
                history: mockHistory,
                currentUserId: mockHistory.buyerId
            )
        }
        .padding()
    }
    .background(ApocalypseTheme.background)
}
