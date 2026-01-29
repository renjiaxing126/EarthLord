//
//  MyTradeOffersView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  我的挂单列表
//

import SwiftUI

/// 挂单筛选类型
enum OfferFilter: String, CaseIterable {
    case all = "全部"
    case active = "进行中"
    case completed = "已完成"
    case cancelled = "已取消"

    var status: TradeStatus? {
        switch self {
        case .all: return nil
        case .active: return .active
        case .completed: return .completed
        case .cancelled: return .cancelled
        }
    }
}

/// 我的挂单视图
struct MyTradeOffersView: View {
    @StateObject private var tradeManager = TradeManager.shared
    @State private var selectedOffer: TradeOffer?
    @State private var selectedFilter: OfferFilter = .all
    @State private var isCancelling = false

    /// 过滤后的挂单列表
    private var filteredOffers: [TradeOffer] {
        if selectedFilter == .all {
            return tradeManager.myOffers
        }
        return tradeManager.myOffers.filter { $0.status == selectedFilter.status }
    }

    var body: some View {
        ZStack {
            if tradeManager.isLoading && tradeManager.myOffers.isEmpty {
                loadingView
            } else if tradeManager.myOffers.isEmpty {
                emptyStateView
            } else {
                offersList
            }
        }
        .sheet(item: $selectedOffer) { offer in
            TradeOfferDetailView(offer: offer, viewMode: .owner)
        }
    }

    // MARK: - 加载中视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(ApocalypseTheme.primary)

            Text("加载我的挂单...")
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
                    .fill(ApocalypseTheme.info.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "list.bullet.rectangle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(ApocalypseTheme.info.opacity(0.6))
            }

            VStack(spacing: 8) {
                Text("还没有挂单")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("点击右上角 + 按钮\n发布您的第一个交易挂单")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await tradeManager.loadMyOffers()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("刷新")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.info)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .stroke(ApocalypseTheme.info, lineWidth: 1)
                )
            }

            Spacer()
        }
    }

    // MARK: - 挂单列表

    private var offersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // 筛选栏
                filterBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // 结果统计
                HStack {
                    Text("共 \(filteredOffers.count) 个挂单")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    if selectedFilter == .active {
                        Text("• \(activeCount) 个进行中")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.success)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)

                // 挂单卡片
                ForEach(filteredOffers) { offer in
                    TradeOfferCard(
                        offer: offer,
                        viewMode: .owner,
                        onTap: {
                            selectedOffer = offer
                        },
                        onCancel: {
                            Task {
                                await cancelOffer(offer)
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                }

                // 底部间距
                Spacer()
                    .frame(height: 20)
            }
        }
        .refreshable {
            await tradeManager.loadMyOffers()
        }
    }

    // MARK: - 筛选栏

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(OfferFilter.allCases, id: \.self) { filter in
                    filterChip(filter)
                }
            }
        }
    }

    private func filterChip(_ filter: OfferFilter) -> some View {
        let isSelected = selectedFilter == filter
        let count = countForFilter(filter)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 4) {
                Text(filter.rawValue)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? .white.opacity(0.3) : .white.opacity(0.1))
                        )
                }
            }
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? ApocalypseTheme.primary : Color.white.opacity(0.05))
            )
        }
    }

    // MARK: - Helper

    private var activeCount: Int {
        tradeManager.myOffers.filter { $0.status == .active }.count
    }

    private func countForFilter(_ filter: OfferFilter) -> Int {
        switch filter {
        case .all:
            return tradeManager.myOffers.count
        case .active:
            return tradeManager.myOffers.filter { $0.status == .active }.count
        case .completed:
            return tradeManager.myOffers.filter { $0.status == .completed }.count
        case .cancelled:
            return tradeManager.myOffers.filter { $0.status == .cancelled || $0.status == .expired }.count
        }
    }

    private func cancelOffer(_ offer: TradeOffer) async {
        isCancelling = true
        do {
            try await tradeManager.cancelOffer(offerId: offer.id)
        } catch {
            print("取消挂单失败: \(error)")
        }
        isCancelling = false
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        MyTradeOffersView()
            .background(ApocalypseTheme.background)
    }
}
