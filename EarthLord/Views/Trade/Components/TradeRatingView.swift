//
//  TradeRatingView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  交易评价弹窗
//

import SwiftUI

/// 交易评价视图
struct TradeRatingView: View {
    let history: TradeHistory
    let currentUserId: UUID
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tradeManager = TradeManager.shared

    @State private var rating: Int = 5
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    /// 判断当前用户角色
    private var isSeller: Bool {
        history.sellerId == currentUserId
    }

    /// 交易对方名称
    private var counterpartyName: String {
        if isSeller {
            return formatUsername(history.buyerUsername ?? "买家")
        } else {
            return formatUsername(history.sellerUsername ?? "卖家")
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 交易摘要
                tradeSummary

                // 评分区域
                ratingSection

                // 评论输入
                commentSection

                Spacer()

                // 提交按钮
                submitButton
            }
            .padding(20)
            .background(ApocalypseTheme.background)
            .navigationTitle("评价交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("提交失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("评价成功", isPresented: $showSuccess) {
                Button("好的") {
                    dismiss()
                }
            } message: {
                Text("感谢您的评价！")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 交易摘要

    private var tradeSummary: some View {
        VStack(spacing: 12) {
            // 角色标识
            HStack {
                Image(systemName: isSeller ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(isSeller ? ApocalypseTheme.primary : ApocalypseTheme.success)

                Text(isSeller ? "您作为卖家" : "您作为买家")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                Text(formatDate(history.completedAt))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // 交易对方
            HStack {
                Text("交易对方:")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))

                Text(counterpartyName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)

                Spacer()
            }

            // 物品交换简要
            HStack(spacing: 8) {
                // 我获得的
                VStack(alignment: .leading, spacing: 4) {
                    Text("获得")
                        .font(.system(size: 10))
                        .foregroundColor(ApocalypseTheme.success)
                    Text("\(receivedItems.count) 种物品")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))

                // 我付出的
                VStack(alignment: .trailing, spacing: 4) {
                    Text("付出")
                        .font(.system(size: 10))
                        .foregroundColor(ApocalypseTheme.warning)
                    Text("\(givenItems.count) 种物品")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - 评分区域

    private var ratingSection: some View {
        VStack(spacing: 16) {
            Text("请为这次交易评分")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)

            // 星星评分
            HStack(spacing: 16) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            rating = star
                        }
                    } label: {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 36))
                            .foregroundColor(star <= rating ? .yellow : .gray.opacity(0.3))
                            .scaleEffect(star <= rating ? 1.1 : 1.0)
                    }
                }
            }

            // 评分说明
            Text(ratingDescription)
                .font(.system(size: 13))
                .foregroundColor(ratingColor)
        }
    }

    private var ratingDescription: String {
        switch rating {
        case 1: return "非常不满意"
        case 2: return "不太满意"
        case 3: return "一般"
        case 4: return "满意"
        case 5: return "非常满意"
        default: return ""
        }
    }

    private var ratingColor: Color {
        switch rating {
        case 1: return ApocalypseTheme.danger
        case 2: return ApocalypseTheme.warning
        case 3: return .white.opacity(0.6)
        case 4: return ApocalypseTheme.success
        case 5: return .yellow
        default: return .white.opacity(0.6)
        }
    }

    // MARK: - 评论区域

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("评价内容（可选）")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            TextField("写下您对这次交易的感受...", text: $comment, axis: .vertical)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .lineLimit(3...5)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                )

            Text("\(comment.count)/200")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .onChange(of: comment) { _, newValue in
            if newValue.count > 200 {
                comment = String(newValue.prefix(200))
            }
        }
    }

    // MARK: - 提交按钮

    private var submitButton: some View {
        Button {
            Task {
                await submitRating()
            }
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("提交评价")
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSubmitting ? ApocalypseTheme.primary.opacity(0.5) : ApocalypseTheme.primary)
            )
        }
        .disabled(isSubmitting)
    }

    // MARK: - 提交逻辑

    private func submitRating() async {
        isSubmitting = true

        do {
            try await tradeManager.rateTrade(
                historyId: history.id,
                rating: rating,
                comment: comment.isEmpty ? nil : comment
            )
            // 重新加载交易历史以更新列表
            await tradeManager.loadHistory()
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isSubmitting = false
    }

    // MARK: - Helper

    private var receivedItems: [TradeItem] {
        if isSeller {
            return history.itemsExchanged.buyerOffered
        } else {
            return history.itemsExchanged.sellerOffered
        }
    }

    private var givenItems: [TradeItem] {
        if isSeller {
            return history.itemsExchanged.sellerOffered
        } else {
            return history.itemsExchanged.buyerOffered
        }
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
                TradeItem(itemId: "water_bottle", quantity: 5)
            ],
            buyerOffered: [
                TradeItem(itemId: "first_aid_kit", quantity: 1)
            ]
        ),
        completedAt: Date(),
        sellerRating: nil,
        buyerRating: nil,
        sellerComment: nil,
        buyerComment: nil
    )

    return TradeRatingView(
        history: mockHistory,
        currentUserId: mockHistory.sellerId
    )
}
