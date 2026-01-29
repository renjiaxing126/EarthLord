//
//  TradeManager.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  交易管理器 - 管理玩家间物品交易
//

import Foundation
import Combine
import Supabase

/// 交易管理器
/// 负责管理交易挂单、接受交易、交易历史和评价
@MainActor
class TradeManager: ObservableObject {

    // MARK: - Singleton

    static let shared = TradeManager()

    // MARK: - Published Properties

    /// 我的挂单列表
    @Published var myOffers: [TradeOffer] = []

    /// 可接受的挂单列表（市场）
    @Published var availableOffers: [TradeOffer] = []

    /// 交易历史
    @Published var tradeHistory: [TradeHistory] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    /// Supabase 服务
    private let supabase = SupabaseService.shared

    /// 默认挂单有效期（24小时）
    private let defaultExpirationHours: Int = 24

    // MARK: - Initialization

    private init() {
        print("🔄 TradeManager 初始化完成")
    }

    // MARK: - Create Offer

    /// 创建交易挂单
    /// - Parameters:
    ///   - offeringItems: 提供的物品列表
    ///   - requestingItems: 想要的物品列表
    ///   - message: 附加消息（可选）
    ///   - expirationHours: 有效期小时数（默认24小时）
    /// - Returns: 创建的挂单
    @discardableResult
    func createOffer(
        offeringItems: [TradeItem],
        requestingItems: [TradeItem],
        message: String? = nil,
        expirationHours: Int? = nil
    ) async throws -> TradeOffer {
        print("📝 [TradeManager] 创建交易挂单")

        // 1. 获取当前用户
        guard let user = try? await supabase.auth.user() else {
            throw TradeError.userNotLoggedIn
        }

        // 2. 检查库存是否充足
        let playerResources = await InventoryManager.shared.getResourceCounts()
        var insufficientItems: [String: Int] = [:]

        for item in offeringItems {
            let available = playerResources[item.itemId] ?? 0
            if available < item.quantity {
                insufficientItems[item.itemId] = item.quantity - available
            }
        }

        if !insufficientItems.isEmpty {
            print("❌ [TradeManager] 物品不足: \(insufficientItems)")
            throw TradeError.insufficientItems(insufficientItems)
        }

        // 3. 扣除物品（锁定）
        for item in offeringItems {
            await InventoryManager.shared.removeItem(itemId: item.itemId, quantity: item.quantity)
        }

        // 4. 计算过期时间
        let hours = expirationHours ?? defaultExpirationHours
        let expiresAt = Date().addingTimeInterval(TimeInterval(hours * 3600))

        // 5. 获取用户名（使用 email）
        let username = user.email ?? "未知用户"

        // 6. 创建挂单数据
        let newOffer = InsertTradeOffer(
            ownerId: user.id.uuidString,
            ownerUsername: username,
            offeringItems: offeringItems,
            requestingItems: requestingItems,
            status: TradeStatus.active.rawValue,
            message: message,
            expiresAt: ISO8601DateFormatter().string(from: expiresAt)
        )

        do {
            let inserted: [TradeOffer] = try await supabase
                .from("trade_offers")
                .insert(newOffer)
                .select()
                .execute()
                .value

            guard let offer = inserted.first else {
                // 回滚：恢复物品
                await restoreItems(offeringItems)
                throw TradeError.databaseError("插入挂单失败")
            }

            // 7. 添加到本地列表
            myOffers.insert(offer, at: 0)

            // 8. 发送通知
            NotificationCenter.default.post(name: .tradeOfferCreated, object: offer)

            print("✅ [TradeManager] 挂单创建成功: \(offer.id)")
            return offer

        } catch let error as TradeError {
            // 回滚：恢复物品
            await restoreItems(offeringItems)
            throw error
        } catch {
            // 回滚：恢复物品
            await restoreItems(offeringItems)
            throw TradeError.databaseError(error.localizedDescription)
        }
    }

    // MARK: - Accept Offer

    /// 接受交易挂单（使用数据库事务保证原子性）
    /// - Parameter offerId: 挂单 ID
    /// - Returns: 创建的交易历史记录
    @discardableResult
    func acceptOffer(offerId: UUID) async throws -> TradeHistory {
        print("🤝 [TradeManager] 接受交易挂单: \(offerId)")

        // 1. 获取当前用户（买家）
        guard let buyer = try? await supabase.auth.user() else {
            throw TradeError.userNotLoggedIn
        }

        // 2. 查询挂单详情（用于客户端预检查）
        let offers: [TradeOffer] = try await supabase
            .from("trade_offers")
            .select()
            .eq("id", value: offerId.uuidString)
            .execute()
            .value

        guard let offer = offers.first else {
            throw TradeError.offerNotFound
        }

        // 3. 客户端预检查（减少不必要的 RPC 调用）
        guard offer.status == .active else {
            throw TradeError.offerNotActive
        }

        guard !offer.isExpired else {
            throw TradeError.offerExpired
        }

        guard offer.ownerId != buyer.id else {
            throw TradeError.cannotAcceptOwnOffer
        }

        // 4. 检查买家库存（requestingItems 是卖家想要的，买家需要提供）
        let buyerResources = await InventoryManager.shared.getResourceCounts()
        var insufficientItems: [String: Int] = [:]

        for item in offer.requestingItems {
            let available = buyerResources[item.itemId] ?? 0
            if available < item.quantity {
                insufficientItems[item.itemId] = item.quantity - available
            }
        }

        if !insufficientItems.isEmpty {
            print("❌ [TradeManager] 买家物品不足: \(insufficientItems)")
            throw TradeError.insufficientItems(insufficientItems)
        }

        // 5. 调用数据库事务函数（原子操作：锁定、验证、扣除、转移、记录）
        let buyerUsername = buyer.email ?? "未知用户"

        do {
            let response = try await supabase.rpc(
                "accept_trade_offer",
                params: [
                    "p_offer_id": offerId.uuidString,
                    "p_buyer_id": buyer.id.uuidString,
                    "p_buyer_username": buyerUsername
                ]
            ).execute()

            // 解析返回结果
            struct AcceptTradeResult: Decodable {
                let success: Bool
                let historyId: UUID
                let offerId: UUID

                enum CodingKeys: String, CodingKey {
                    case success
                    case historyId = "history_id"
                    case offerId = "offer_id"
                }
            }

            let decoder = JSONDecoder()
            let resultData = response.data
            let result = try decoder.decode(AcceptTradeResult.self, from: resultData)

            // 6. 刷新本地库存数据
            await InventoryManager.shared.loadInventory()

            // 7. 加载新创建的交易历史记录
            let histories: [TradeHistory] = try await supabase
                .from("trade_history")
                .select()
                .eq("id", value: result.historyId.uuidString)
                .execute()
                .value

            guard let history = histories.first else {
                throw TradeError.databaseError("获取交易历史失败")
            }

            // 8. 更新本地列表
            if let index = availableOffers.firstIndex(where: { $0.id == offerId }) {
                availableOffers.remove(at: index)
            }
            tradeHistory.insert(history, at: 0)

            // 9. 发送通知
            NotificationCenter.default.post(name: .tradeCompleted, object: history)

            print("✅ [TradeManager] 交易完成: \(history.id)")
            return history

        } catch let error as TradeError {
            throw error
        } catch {
            // 解析数据库错误
            let errorMessage = error.localizedDescription
            if errorMessage.contains("OFFER_NOT_FOUND") {
                throw TradeError.offerNotFound
            } else if errorMessage.contains("OFFER_NOT_ACTIVE") {
                throw TradeError.offerNotActive
            } else if errorMessage.contains("OFFER_EXPIRED") {
                throw TradeError.offerExpired
            } else if errorMessage.contains("CANNOT_ACCEPT_OWN_OFFER") {
                throw TradeError.cannotAcceptOwnOffer
            } else {
                throw TradeError.databaseError(errorMessage)
            }
        }
    }

    // MARK: - Cancel Offer

    /// 取消交易挂单
    /// - Parameter offerId: 挂单 ID
    func cancelOffer(offerId: UUID) async throws {
        print("❌ [TradeManager] 取消交易挂单: \(offerId)")

        // 1. 获取当前用户
        guard let user = try? await supabase.auth.user() else {
            throw TradeError.userNotLoggedIn
        }

        // 2. 查询挂单详情
        let offers: [TradeOffer] = try await supabase
            .from("trade_offers")
            .select()
            .eq("id", value: offerId.uuidString)
            .eq("owner_id", value: user.id.uuidString)
            .execute()
            .value

        guard let offer = offers.first else {
            throw TradeError.offerNotFound
        }

        // 3. 验证状态
        guard offer.status == .active else {
            throw TradeError.offerNotActive
        }

        // 4. 更新状态为已取消
        let updateData = UpdateTradeOffer(
            status: TradeStatus.cancelled.rawValue,
            completedAt: nil,
            completedByUserId: nil,
            completedByUsername: nil
        )

        try await supabase
            .from("trade_offers")
            .update(updateData)
            .eq("id", value: offerId.uuidString)
            .execute()

        // 5. 退还物品
        await restoreItems(offer.offeringItems)

        // 6. 更新本地列表
        if let index = myOffers.firstIndex(where: { $0.id == offerId }) {
            myOffers[index].status = .cancelled
        }

        // 7. 发送通知
        NotificationCenter.default.post(name: .tradeOfferCancelled, object: offerId)

        print("✅ [TradeManager] 挂单已取消，物品已退还")
    }

    // MARK: - Load My Offers

    /// 加载我的挂单列表
    func loadMyOffers() async {
        isLoading = true
        errorMessage = nil

        print("📦 [TradeManager] 加载我的挂单")

        do {
            let user = try await supabase.auth.user()

            let offers: [TradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("owner_id", value: user.id.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            // 处理过期挂单
            var processedOffers: [TradeOffer] = []
            for var offer in offers {
                if offer.status == .active && offer.isExpired {
                    // 标记为过期并退还物品
                    await handleExpiredOffer(offer)
                    offer.status = .expired
                }
                processedOffers.append(offer)
            }

            myOffers = processedOffers
            print("✅ [TradeManager] 加载成功，共 \(myOffers.count) 个挂单")

        } catch {
            errorMessage = "加载挂单失败: \(error.localizedDescription)"
            print("❌ [TradeManager] 加载失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - Load Available Offers

    /// 加载市场挂单列表（可接受的挂单）
    func loadAvailableOffers() async {
        isLoading = true
        errorMessage = nil

        print("📦 [TradeManager] 加载市场挂单")

        do {
            let user = try await supabase.auth.user()

            let offers: [TradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("status", value: "active")
                .neq("owner_id", value: user.id.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            // 过滤已过期的挂单
            availableOffers = offers.filter { !$0.isExpired }
            print("✅ [TradeManager] 加载成功，共 \(availableOffers.count) 个可交易挂单")

        } catch {
            errorMessage = "加载市场失败: \(error.localizedDescription)"
            print("❌ [TradeManager] 加载失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - Load History

    /// 加载交易历史
    func loadHistory() async {
        isLoading = true
        errorMessage = nil

        print("📦 [TradeManager] 加载交易历史")

        do {
            let user = try await supabase.auth.user()

            // 查询作为买家或卖家的交易记录
            let history: [TradeHistory] = try await supabase
                .from("trade_history")
                .select()
                .or("seller_id.eq.\(user.id.uuidString),buyer_id.eq.\(user.id.uuidString)")
                .order("completed_at", ascending: false)
                .execute()
                .value

            tradeHistory = history
            print("✅ [TradeManager] 加载成功，共 \(tradeHistory.count) 条交易记录")

        } catch {
            errorMessage = "加载历史失败: \(error.localizedDescription)"
            print("❌ [TradeManager] 加载失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - Rate Trade

    /// 评价交易
    /// - Parameters:
    ///   - historyId: 交易历史 ID
    ///   - rating: 评分（1-5）
    ///   - comment: 评论（可选）
    func rateTrade(historyId: UUID, rating: Int, comment: String? = nil) async throws {
        print("⭐ [TradeManager] 评价交易: \(historyId), 评分: \(rating)")

        // 1. 验证评分范围
        guard rating >= 1 && rating <= 5 else {
            throw TradeError.invalidRating
        }

        // 2. 获取当前用户
        guard let user = try? await supabase.auth.user() else {
            throw TradeError.userNotLoggedIn
        }

        // 3. 查询交易历史
        let histories: [TradeHistory] = try await supabase
            .from("trade_history")
            .select()
            .eq("id", value: historyId.uuidString)
            .execute()
            .value

        guard let history = histories.first else {
            throw TradeError.databaseError("交易记录不存在")
        }

        // 4. 确定用户角色并检查是否已评价
        let isSeller = history.sellerId == user.id
        let isBuyer = history.buyerId == user.id

        guard isSeller || isBuyer else {
            throw TradeError.databaseError("您不是该交易的参与者")
        }

        if isSeller && history.sellerRating != nil {
            throw TradeError.alreadyRated
        }

        if isBuyer && history.buyerRating != nil {
            throw TradeError.alreadyRated
        }

        // 5. 更新评价
        var updateData: UpdateTradeRating
        if isSeller {
            // 卖家评价买家
            updateData = UpdateTradeRating(
                sellerRating: rating,
                buyerRating: nil,
                sellerComment: comment,
                buyerComment: nil
            )
        } else {
            // 买家评价卖家
            updateData = UpdateTradeRating(
                sellerRating: nil,
                buyerRating: rating,
                sellerComment: nil,
                buyerComment: comment
            )
        }

        try await supabase
            .from("trade_history")
            .update(updateData)
            .eq("id", value: historyId.uuidString)
            .execute()

        // 6. 更新本地列表
        if let index = tradeHistory.firstIndex(where: { $0.id == historyId }) {
            if isSeller {
                tradeHistory[index].sellerRating = rating
                tradeHistory[index].sellerComment = comment
            } else {
                tradeHistory[index].buyerRating = rating
                tradeHistory[index].buyerComment = comment
            }
        }

        print("✅ [TradeManager] 评价成功")
    }

    // MARK: - Private Helpers

    /// 恢复物品到库存
    private func restoreItems(_ items: [TradeItem]) async {
        print("🔄 [TradeManager] 恢复物品到库存")

        let rewards = items.map { item in
            GeneratedRewardItem(
                id: UUID().uuidString,
                itemId: item.itemId,
                name: item.itemId,
                icon: "",
                rarity: .common,
                quantity: item.quantity,
                category: "",
                isAIGenerated: false,
                aiStory: nil
            )
        }

        await InventoryManager.shared.addItems(rewards, source: "trade_refund")
    }

    /// 处理过期挂单
    private func handleExpiredOffer(_ offer: TradeOffer) async {
        print("⏰ [TradeManager] 处理过期挂单: \(offer.id)")

        // 1. 更新数据库状态
        let updateData = UpdateTradeOffer(
            status: TradeStatus.expired.rawValue,
            completedAt: nil,
            completedByUserId: nil,
            completedByUsername: nil
        )

        do {
            try await supabase
                .from("trade_offers")
                .update(updateData)
                .eq("id", value: offer.id.uuidString)
                .eq("status", value: "active")  // 只更新仍为 active 的
                .execute()

            // 2. 退还物品
            await restoreItems(offer.offeringItems)

            print("✅ [TradeManager] 过期挂单已处理，物品已退还")

        } catch {
            print("❌ [TradeManager] 处理过期挂单失败: \(error)")
        }
    }

    // MARK: - Utility Methods

    /// 获取用户交易统计
    func getUserTradeStats() async -> (totalTrades: Int, averageRating: Double?) {
        guard let user = try? await supabase.auth.user() else {
            return (0, nil)
        }

        let sellerTrades = tradeHistory.filter { $0.sellerId == user.id }
        let buyerTrades = tradeHistory.filter { $0.buyerId == user.id }

        let totalTrades = sellerTrades.count + buyerTrades.count

        // 计算作为卖家收到的评价
        let sellerRatings = sellerTrades.compactMap { $0.buyerRating }
        // 计算作为买家收到的评价
        let buyerRatings = buyerTrades.compactMap { $0.sellerRating }

        let allRatings = sellerRatings + buyerRatings

        if allRatings.isEmpty {
            return (totalTrades, nil)
        }

        let averageRating = Double(allRatings.reduce(0, +)) / Double(allRatings.count)
        return (totalTrades, averageRating)
    }

    /// 刷新所有数据
    func refreshAll() async {
        await loadMyOffers()
        await loadAvailableOffers()
        await loadHistory()
    }
}
