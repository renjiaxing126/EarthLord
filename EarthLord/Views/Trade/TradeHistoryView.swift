//
//  TradeHistoryView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  交易历史列表
//

import SwiftUI
import Supabase

/// 交易历史视图
struct TradeHistoryView: View {
    @StateObject private var tradeManager = TradeManager.shared
    @State private var currentUserId: UUID?
    @State private var selectedHistory: TradeHistory?
    @State private var showRatingSheet = false

    var body: some View {
        ZStack {
            if tradeManager.isLoading && tradeManager.tradeHistory.isEmpty {
                loadingView
            } else if tradeManager.tradeHistory.isEmpty {
                emptyStateView
            } else {
                historyList
            }
        }
        .task {
            await loadCurrentUserId()
        }
        .sheet(isPresented: $showRatingSheet) {
            if let history = selectedHistory, let userId = currentUserId {
                TradeRatingView(history: history, currentUserId: userId)
            }
        }
    }

    // MARK: - 加载中视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(ApocalypseTheme.primary)

            Text("加载交易历史...")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(ApocalypseTheme.warning.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "clock.fill")
                    .font(.system(size: 44))
                    .foregroundColor(ApocalypseTheme.warning.opacity(0.6))
            }

            VStack(spacing: 8) {
                Text("暂无交易记录")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("完成交易后\n交易记录将显示在这里")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await tradeManager.loadHistory()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("刷新")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.warning)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .stroke(ApocalypseTheme.warning, lineWidth: 1)
                )
            }

            Spacer()
        }
    }

    // MARK: - 历史列表

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // 统计信息
                statsHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // 历史卡片
                ForEach(tradeManager.tradeHistory) { history in
                    if let userId = currentUserId {
                        TradeHistoryCard(
                            history: history,
                            currentUserId: userId
                        ) {
                            selectedHistory = history
                            showRatingSheet = true
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // 底部间距
                Spacer()
                    .frame(height: 20)
            }
        }
        .refreshable {
            await tradeManager.loadHistory()
        }
    }

    // MARK: - 统计头部

    private var statsHeader: some View {
        HStack(spacing: 16) {
            // 总交易数
            statItem(
                value: "\(tradeManager.tradeHistory.count)",
                label: "总交易",
                icon: "arrow.left.arrow.right",
                color: ApocalypseTheme.info
            )

            // 作为卖家
            statItem(
                value: "\(sellerCount)",
                label: "作为卖家",
                icon: "arrow.up.circle.fill",
                color: ApocalypseTheme.primary
            )

            // 作为买家
            statItem(
                value: "\(buyerCount)",
                label: "作为买家",
                icon: "arrow.down.circle.fill",
                color: ApocalypseTheme.success
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)

                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 计算属性

    private var sellerCount: Int {
        guard let userId = currentUserId else { return 0 }
        return tradeManager.tradeHistory.filter { $0.sellerId == userId }.count
    }

    private var buyerCount: Int {
        guard let userId = currentUserId else { return 0 }
        return tradeManager.tradeHistory.filter { $0.buyerId == userId }.count
    }

    // MARK: - Helper

    private func loadCurrentUserId() async {
        do {
            let user = try await SupabaseService.shared.auth.user()
            currentUserId = user.id
        } catch {
            print("获取用户ID失败: \(error)")
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        TradeHistoryView()
            .background(ApocalypseTheme.background)
    }
}
