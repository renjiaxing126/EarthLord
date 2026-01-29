//
//  TradeOfferDetailView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  交易挂单详情页
//

import SwiftUI

/// 详情页视图模式
enum TradeDetailViewMode {
    case owner   // 我的挂单（可取消）
    case buyer   // 市场挂单（可接受）
}

/// 交易挂单详情视图
struct TradeOfferDetailView: View {
    let offer: TradeOffer
    let viewMode: TradeDetailViewMode
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tradeManager = TradeManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared

    @State private var resourceCounts: [String: Int] = [:]
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showCancelConfirm = false
    @State private var showAcceptConfirm = false
    @State private var showSuccess = false
    @State private var successMessage = ""

    /// 检查是否有足够物品接受交易
    private var canAccept: Bool {
        guard viewMode == .buyer && offer.status == .active else { return false }
        return offer.requestingItems.allSatisfy { item in
            (resourceCounts[item.itemId] ?? 0) >= item.quantity
        }
    }

    /// 缺少的物品
    private var missingItems: [(String, Int)] {
        offer.requestingItems.compactMap { item in
            let available = resourceCounts[item.itemId] ?? 0
            let needed = item.quantity
            if available < needed {
                return (item.itemId, needed - available)
            }
            return nil
        }
    }

    /// 接受确认消息
    private var acceptConfirmMessage: String {
        let getNames = offer.offeringItems.map { item in
            let def = getItemDefinition(item.itemId)
            return "\(def?.name ?? item.itemId) x\(item.quantity)"
        }.joined(separator: "、")

        let payNames = offer.requestingItems.map { item in
            let def = getItemDefinition(item.itemId)
            return "\(def?.name ?? item.itemId) x\(item.quantity)"
        }.joined(separator: "、")

        return "您将获得: \(getNames)\n\n您需支付: \(payNames)\n\n交易确认后不可撤销"
    }

    private func getItemDefinition(_ itemId: String) -> RewardItemDefinition? {
        let allItems = RewardGenerator.commonItems + RewardGenerator.rareItems + RewardGenerator.epicItems
        return allItems.first { $0.id == itemId }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 状态标签
                    statusHeader

                    // 卖家信息
                    sellerInfo

                    // 对方提供的物品
                    offeringItemsSection

                    // 你需要支付的物品（买家模式显示库存状态）
                    requestingItemsSection

                    // 附加消息
                    if let message = offer.message, !message.isEmpty {
                        messageSection(message)
                    }

                    // 操作按钮
                    actionButtons
                }
                .padding(16)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("挂单详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .task {
                resourceCounts = await inventoryManager.getResourceCounts()
            }
            .confirmationDialog("确认取消", isPresented: $showCancelConfirm, titleVisibility: .visible) {
                Button("确认取消挂单", role: .destructive) {
                    Task { await cancelOffer() }
                }
                Button("返回", role: .cancel) {}
            } message: {
                Text("取消后，物品将退还到您的背包")
            }
            .confirmationDialog("确认接受交易", isPresented: $showAcceptConfirm, titleVisibility: .visible) {
                Button("确认交易") {
                    Task { await acceptOffer() }
                }
                Button("返回", role: .cancel) {}
            } message: {
                Text(acceptConfirmMessage)
            }
            .alert("操作失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("操作成功", isPresented: $showSuccess) {
                Button("好的") {
                    dismiss()
                }
            } message: {
                Text(successMessage)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 状态头部

    private var statusHeader: some View {
        HStack {
            // 状态标签
            HStack(spacing: 6) {
                Circle()
                    .fill(offer.status.color)
                    .frame(width: 8, height: 8)

                Text(offer.status.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(offer.status.color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(offer.status.color.opacity(0.15))
            )

            Spacer()

            // 剩余时间（仅活跃状态）
            if offer.status == .active {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                    Text(offer.formattedRemainingTime)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(offer.remainingTime < 3600 ? ApocalypseTheme.danger : ApocalypseTheme.textSecondary)
            }
        }
    }

    // MARK: - 卖家信息

    private var sellerInfo: some View {
        HStack(spacing: 12) {
            // 头像
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewMode == .owner ? "我的挂单" : "卖家")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))

                Text(formatUsername(offer.ownerUsername))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            Spacer()

            // 创建时间
            VStack(alignment: .trailing, spacing: 4) {
                Text("发布于")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))

                Text(formatDate(offer.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - 对方提供的物品

    private var offeringItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(ApocalypseTheme.success)
                Text(viewMode == .owner ? "我提供的物品" : "您将获得")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(offer.offeringItems) { item in
                    TradeItemRow(itemId: item.itemId, quantity: item.quantity)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.success.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.success.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 你需要支付的物品

    private var requestingItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(ApocalypseTheme.warning)
                Text(viewMode == .owner ? "我想要的物品" : "您需要支付")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()

                // 买家模式显示库存状态
                if viewMode == .buyer {
                    Text(canAccept ? "库存充足" : "库存不足")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(canAccept ? ApocalypseTheme.success : ApocalypseTheme.danger)
                }
            }

            VStack(spacing: 8) {
                ForEach(offer.requestingItems) { item in
                    if viewMode == .buyer {
                        TradeItemRow(
                            itemId: item.itemId,
                            quantity: item.quantity,
                            showStock: true,
                            stockQuantity: resourceCounts[item.itemId] ?? 0
                        )
                    } else {
                        TradeItemRow(itemId: item.itemId, quantity: item.quantity)
                    }
                }
            }

            // 缺少物品提示
            if viewMode == .buyer && !missingItems.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text("缺少 \(missingItems.count) 种物品，无法接受此交易")
                        .font(.system(size: 12))
                }
                .foregroundColor(ApocalypseTheme.danger)
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ApocalypseTheme.danger.opacity(0.1))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.warning.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.warning.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 附加消息

    private func messageSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.bubble.fill")
                    .foregroundColor(.white.opacity(0.5))
                Text("卖家留言")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                )
        }
    }

    // MARK: - 操作按钮

    @ViewBuilder
    private var actionButtons: some View {
        if offer.status == .active {
            if viewMode == .owner {
                // 取消按钮
                Button {
                    showCancelConfirm = true
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                            Text("取消挂单")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ApocalypseTheme.danger)
                    )
                }
                .disabled(isProcessing)
            } else {
                // 接受按钮
                Button {
                    showAcceptConfirm = true
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text("接受交易")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(canAccept ? ApocalypseTheme.success : ApocalypseTheme.success.opacity(0.3))
                    )
                }
                .disabled(!canAccept || isProcessing)
            }
        } else {
            // 非活跃状态显示提示
            HStack {
                Image(systemName: "info.circle.fill")
                Text("此挂单已\(offer.status.displayName)，无法操作")
            }
            .font(.system(size: 14))
            .foregroundColor(ApocalypseTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    // MARK: - 操作方法

    private func cancelOffer() async {
        isProcessing = true

        do {
            try await tradeManager.cancelOffer(offerId: offer.id)
            successMessage = "挂单已取消，物品已退还到背包"
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isProcessing = false
    }

    private func acceptOffer() async {
        isProcessing = true

        do {
            _ = try await tradeManager.acceptOffer(offerId: offer.id)
            successMessage = "交易成功！物品已存入您的背包"
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isProcessing = false
    }

    // MARK: - Helper

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
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 预览

#Preview {
    let mockOffer = TradeOffer(
        id: UUID(),
        ownerId: UUID(),
        ownerUsername: "test@example.com",
        offeringItems: [
            TradeItem(itemId: "water_bottle", quantity: 5),
            TradeItem(itemId: "bandage", quantity: 3)
        ],
        requestingItems: [
            TradeItem(itemId: "first_aid_kit", quantity: 1)
        ],
        status: .active,
        message: "急需急救包，真诚交换，价格可商量",
        createdAt: Date(),
        expiresAt: Date().addingTimeInterval(3600 * 12),
        completedAt: nil,
        completedByUserId: nil,
        completedByUsername: nil
    )

    return TradeOfferDetailView(offer: mockOffer, viewMode: .buyer)
}
