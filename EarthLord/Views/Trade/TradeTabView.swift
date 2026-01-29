//
//  TradeTabView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  交易主页面 - 分段切换
//

import SwiftUI

/// 交易分段类型
enum TradeSegment: String, CaseIterable {
    case market = "交易市场"
    case myOffers = "我的挂单"
    case history = "交易历史"

    var icon: String {
        switch self {
        case .market: return "storefront.fill"
        case .myOffers: return "list.bullet.rectangle.fill"
        case .history: return "clock.fill"
        }
    }
}

/// 交易主页面
struct TradeTabView: View {
    @StateObject private var tradeManager = TradeManager.shared
    @State private var selectedSegment: TradeSegment = .market
    @State private var showCreateOffer = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // 分段选择器
            segmentPicker
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            // 内容视图
            contentView
        }
        .background(ApocalypseTheme.background)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateOffer = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .sheet(isPresented: $showCreateOffer) {
            CreateTradeOfferView()
        }
        .onAppear {
            Task {
                await tradeManager.refreshAll()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tradeOfferCreated)) { _ in
            // 发布成功后切换到"我的挂单"
            withAnimation {
                selectedSegment = .myOffers
            }
        }
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onChange(of: tradeManager.errorMessage) { _, newValue in
            if let error = newValue {
                errorMessage = error
                showError = true
            }
        }
    }

    // MARK: - 分段选择器

    private var segmentPicker: some View {
        Picker("选择分段", selection: $selectedSegment) {
            ForEach(TradeSegment.allCases, id: \.self) { segment in
                Text(segment.rawValue)
                    .tag(segment)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - 内容视图

    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case .market:
            TradeMarketView()
        case .myOffers:
            MyTradeOffersView()
        case .history:
            TradeHistoryView()
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        TradeTabView()
            .navigationTitle("交易")
    }
}
