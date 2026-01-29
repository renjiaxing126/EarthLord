//
//  TradeMarketView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  交易市场列表
//

import SwiftUI

/// 交易市场视图
struct TradeMarketView: View {
    @StateObject private var tradeManager = TradeManager.shared
    @State private var selectedOffer: TradeOffer?
    @State private var searchText = ""

    /// 过滤后的挂单列表
    private var filteredOffers: [TradeOffer] {
        if searchText.isEmpty {
            return tradeManager.availableOffers
        }
        return tradeManager.availableOffers.filter { offer in
            // 搜索物品名称
            let allItems = offer.offeringItems + offer.requestingItems
            let itemNames = allItems.compactMap { item -> String? in
                let definition = getItemDefinition(item.itemId)
                return definition?.name ?? item.itemId
            }
            return itemNames.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        ZStack {
            if tradeManager.isLoading && tradeManager.availableOffers.isEmpty {
                loadingView
            } else if tradeManager.availableOffers.isEmpty {
                emptyStateView
            } else {
                offersList
            }
        }
        .sheet(item: $selectedOffer) { offer in
            TradeOfferDetailView(offer: offer, viewMode: .buyer)
        }
    }

    // MARK: - 加载中视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(ApocalypseTheme.primary)

            Text("加载市场挂单...")
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
                    .fill(ApocalypseTheme.primary.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "storefront.fill")
                    .font(.system(size: 44))
                    .foregroundColor(ApocalypseTheme.primary.opacity(0.6))
            }

            VStack(spacing: 8) {
                Text("暂无交易挂单")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("市场空空如也\n快去发布第一个挂单吧")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await tradeManager.loadAvailableOffers()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("刷新")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .stroke(ApocalypseTheme.primary, lineWidth: 1)
                )
            }

            Spacer()
        }
    }

    // MARK: - 挂单列表

    private var offersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // 搜索栏
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // 结果统计
                HStack {
                    Text("共 \(filteredOffers.count) 个挂单")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)

                // 挂单卡片
                ForEach(filteredOffers) { offer in
                    TradeOfferCard(
                        offer: offer,
                        viewMode: .market
                    ) {
                        selectedOffer = offer
                    }
                    .padding(.horizontal, 16)
                }

                // 底部间距
                Spacer()
                    .frame(height: 20)
            }
        }
        .refreshable {
            await tradeManager.loadAvailableOffers()
        }
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("搜索物品名称...", text: $searchText)
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

    // MARK: - Helper

    private func getItemDefinition(_ itemId: String) -> RewardItemDefinition? {
        let allItems = RewardGenerator.commonItems + RewardGenerator.rareItems + RewardGenerator.epicItems
        return allItems.first { $0.id == itemId }
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        TradeMarketView()
            .background(ApocalypseTheme.background)
    }
}
