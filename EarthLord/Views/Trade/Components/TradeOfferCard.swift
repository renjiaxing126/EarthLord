//
//  TradeOfferCard.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  交易挂单卡片组件
//

import SwiftUI

/// 卡片视图模式
enum TradeCardViewMode {
    case owner   // 我的挂单（可取消）
    case market  // 市场挂单（可接受）
}

/// 交易挂单卡片组件
struct TradeOfferCard: View {
    let offer: TradeOffer
    let viewMode: TradeCardViewMode
    let onTap: () -> Void
    var onCancel: (() -> Void)? = nil

    @State private var showCancelConfirm = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // 顶部：用户名 + 状态/剩余时间
                HStack {
                    userInfo
                    Spacer()
                    statusBadge
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                // 中间：物品交换预览
                HStack(spacing: 12) {
                    itemsPreview(offer.offeringItems, label: "出")

                    Image(systemName: "arrow.right.arrow.left")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.primary)

                    itemsPreview(offer.requestingItems, label: "求")
                }

                // 附加消息（如果有）
                if let message = offer.message, !message.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }

                // 已完成的挂单显示接受者信息
                if offer.status == .completed, let accepterName = offer.completedByUsername {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(ApocalypseTheme.success)
                        Text("被 \(formatUsername(accepterName)) 接受")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.success.opacity(0.8))
                    }
                }

                // 底部：取消按钮（仅owner模式且状态为active）
                if viewMode == .owner && offer.status == .active {
                    cancelButton
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(offer.status.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .confirmationDialog("确认取消", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button("确认取消挂单", role: .destructive) {
                onCancel?()
            }
            Button("返回", role: .cancel) {}
        } message: {
            Text("取消后，物品将退还到您的背包")
        }
    }

    // MARK: - 用户信息

    private var userInfo: some View {
        HStack(spacing: 8) {
            // 用户头像
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 用户名
            Text(displayUsername)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }

    /// 显示用户名（隐藏部分邮箱）
    private var displayUsername: String {
        let username = offer.ownerUsername
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

    // MARK: - 状态标签

    private var statusBadge: some View {
        HStack(spacing: 4) {
            if offer.status == .active {
                // 显示剩余时间
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                Text(offer.formattedRemainingTime)
                    .font(.system(size: 11, weight: .medium))
            } else {
                // 显示状态
                Text(offer.status.displayName)
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(offer.status.color.opacity(0.2))
        )
        .foregroundColor(offer.status.color)
    }

    // MARK: - 物品预览

    private func itemsPreview(_ items: [TradeItem], label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // 标签
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                )

            // 物品列表
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items.prefix(2)) { item in
                    itemRow(item)
                }
                if items.count > 2 {
                    Text("+\(items.count - 2) 更多")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func itemRow(_ item: TradeItem) -> some View {
        let definition = getItemDefinition(item.itemId)

        return HStack(spacing: 6) {
            // 小图标
            ZStack {
                Circle()
                    .fill((definition?.rarity.color ?? .gray).opacity(0.2))
                    .frame(width: 20, height: 20)

                Image(systemName: definition?.icon ?? "cube.fill")
                    .font(.system(size: 9))
                    .foregroundColor(definition?.rarity.color ?? .gray)
            }

            // 名称
            Text(definition?.name ?? item.itemId)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)

            // 数量
            Text("x\(item.quantity)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(definition?.rarity.color ?? .gray)
        }
    }

    // MARK: - 取消按钮

    private var cancelButton: some View {
        Button {
            showCancelConfirm = true
        } label: {
            HStack {
                Image(systemName: "xmark.circle.fill")
                Text("取消挂单")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(ApocalypseTheme.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ApocalypseTheme.danger.opacity(0.15))
            )
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
}

// MARK: - 预览

#Preview {
    let mockOffer = TradeOffer(
        id: UUID(),
        ownerId: UUID(),
        ownerUsername: "test@example.com",
        offeringItems: [
            TradeItem(itemId: "water_bottle", quantity: 3),
            TradeItem(itemId: "bandage", quantity: 2)
        ],
        requestingItems: [
            TradeItem(itemId: "first_aid_kit", quantity: 1)
        ],
        status: .active,
        message: "急需急救包，诚意交换",
        createdAt: Date(),
        expiresAt: Date().addingTimeInterval(3600 * 5),
        completedAt: nil,
        completedByUserId: nil,
        completedByUsername: nil
    )

    ScrollView {
        VStack(spacing: 16) {
            TradeOfferCard(offer: mockOffer, viewMode: .market) {}

            TradeOfferCard(offer: mockOffer, viewMode: .owner, onTap: {}) {
                print("Cancel tapped")
            }
        }
        .padding()
    }
    .background(ApocalypseTheme.background)
}
