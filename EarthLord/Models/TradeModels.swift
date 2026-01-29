//
//  TradeModels.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  交易系统数据模型
//

import Foundation
import SwiftUI

// MARK: - TradeStatus 交易状态

/// 交易状态枚举
enum TradeStatus: String, Codable {
    case active = "active"          // 活跃中
    case completed = "completed"    // 已完成
    case cancelled = "cancelled"    // 已取消
    case expired = "expired"        // 已过期

    var displayName: String {
        switch self {
        case .active: return "交易中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        case .expired: return "已过期"
        }
    }

    var color: Color {
        switch self {
        case .active: return .green
        case .completed: return .blue
        case .cancelled: return .gray
        case .expired: return .orange
        }
    }
}

// MARK: - TradeItem 交易物品条目

/// 交易物品条目（用于 JSONB 存储）
struct TradeItem: Codable, Identifiable, Equatable {
    let itemId: String
    let quantity: Int

    var id: String { itemId }

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case quantity
    }
}

// MARK: - TradeExchangeInfo 交易交换信息

/// 交易交换信息（用于历史记录的 JSONB）
struct TradeExchangeInfo: Codable {
    let sellerOffered: [TradeItem]   // 卖家提供的物品
    let buyerOffered: [TradeItem]    // 买家提供的物品

    enum CodingKeys: String, CodingKey {
        case sellerOffered = "seller_offered"
        case buyerOffered = "buyer_offered"
    }
}

// MARK: - TradeOffer 交易挂单

/// 交易挂单结构体（数据库表映射）
struct TradeOffer: Codable, Identifiable {
    let id: UUID
    let ownerId: UUID
    let ownerUsername: String
    let offeringItems: [TradeItem]      // 卖家提供的物品
    let requestingItems: [TradeItem]    // 卖家想要的物品
    var status: TradeStatus
    let message: String?
    let createdAt: Date
    let expiresAt: Date
    var completedAt: Date?
    var completedByUserId: UUID?
    var completedByUsername: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case ownerUsername = "owner_username"
        case offeringItems = "offering_items"
        case requestingItems = "requesting_items"
        case status
        case message
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case completedAt = "completed_at"
        case completedByUserId = "completed_by_user_id"
        case completedByUsername = "completed_by_username"
    }

    // MARK: - 计算属性

    /// 是否已过期
    var isExpired: Bool {
        Date() > expiresAt
    }

    /// 剩余时间（秒）
    var remainingTime: TimeInterval {
        max(0, expiresAt.timeIntervalSince(Date()))
    }

    /// 格式化剩余时间
    var formattedRemainingTime: String {
        let remaining = remainingTime

        if remaining <= 0 {
            return "已过期"
        } else if remaining < 60 {
            return "\(Int(remaining))秒"
        } else if remaining < 3600 {
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            return "\(minutes)分\(seconds)秒"
        } else if remaining < 86400 {
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            return "\(hours)小时\(minutes)分"
        } else {
            let days = Int(remaining) / 86400
            let hours = (Int(remaining) % 86400) / 3600
            return "\(days)天\(hours)小时"
        }
    }
}

// MARK: - TradeHistory 交易历史

/// 交易历史结构体（数据库表映射）
struct TradeHistory: Codable, Identifiable {
    let id: UUID
    let offerId: UUID?
    let sellerId: UUID
    let sellerUsername: String?
    let buyerId: UUID
    let buyerUsername: String?
    let itemsExchanged: TradeExchangeInfo
    let completedAt: Date
    var sellerRating: Int?
    var buyerRating: Int?
    var sellerComment: String?
    var buyerComment: String?

    enum CodingKeys: String, CodingKey {
        case id
        case offerId = "offer_id"
        case sellerId = "seller_id"
        case sellerUsername = "seller_username"
        case buyerId = "buyer_id"
        case buyerUsername = "buyer_username"
        case itemsExchanged = "items_exchanged"
        case completedAt = "completed_at"
        case sellerRating = "seller_rating"
        case buyerRating = "buyer_rating"
        case sellerComment = "seller_comment"
        case buyerComment = "buyer_comment"
    }
}

// MARK: - InsertTradeOffer 插入用模型

/// 用于插入新挂单的模型
struct InsertTradeOffer: Codable {
    let ownerId: String
    let ownerUsername: String
    let offeringItems: [TradeItem]
    let requestingItems: [TradeItem]
    let status: String
    let message: String?
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case ownerId = "owner_id"
        case ownerUsername = "owner_username"
        case offeringItems = "offering_items"
        case requestingItems = "requesting_items"
        case status
        case message
        case expiresAt = "expires_at"
    }
}

// MARK: - UpdateTradeOffer 更新用模型

/// 用于更新挂单的模型
struct UpdateTradeOffer: Codable {
    let status: String?
    let completedAt: String?
    let completedByUserId: String?
    let completedByUsername: String?

    enum CodingKeys: String, CodingKey {
        case status
        case completedAt = "completed_at"
        case completedByUserId = "completed_by_user_id"
        case completedByUsername = "completed_by_username"
    }
}

// MARK: - InsertTradeHistory 插入用模型

/// 用于插入交易历史的模型
struct InsertTradeHistory: Codable {
    let offerId: String?
    let sellerId: String
    let sellerUsername: String?
    let buyerId: String
    let buyerUsername: String?
    let itemsExchanged: TradeExchangeInfo

    enum CodingKeys: String, CodingKey {
        case offerId = "offer_id"
        case sellerId = "seller_id"
        case sellerUsername = "seller_username"
        case buyerId = "buyer_id"
        case buyerUsername = "buyer_username"
        case itemsExchanged = "items_exchanged"
    }
}

// MARK: - UpdateTradeRating 评价更新模型

/// 用于更新交易评价的模型
struct UpdateTradeRating: Codable {
    let sellerRating: Int?
    let buyerRating: Int?
    let sellerComment: String?
    let buyerComment: String?

    enum CodingKeys: String, CodingKey {
        case sellerRating = "seller_rating"
        case buyerRating = "buyer_rating"
        case sellerComment = "seller_comment"
        case buyerComment = "buyer_comment"
    }
}

// MARK: - TradeError 交易错误

/// 交易相关错误枚举
enum TradeError: Error, LocalizedError {
    case userNotLoggedIn
    case insufficientItems([String: Int])
    case offerNotFound
    case offerExpired
    case offerNotActive
    case cannotAcceptOwnOffer
    case concurrencyConflict
    case invalidRating
    case alreadyRated
    case databaseError(String)

    var errorDescription: String? {
        switch self {
        case .userNotLoggedIn:
            return "用户未登录"
        case .insufficientItems(let missing):
            let items = missing.map { "\($0.key): 缺少\($0.value)" }.joined(separator: ", ")
            return "物品不足: \(items)"
        case .offerNotFound:
            return "挂单不存在"
        case .offerExpired:
            return "挂单已过期"
        case .offerNotActive:
            return "挂单已被其他人接受或已取消"
        case .cannotAcceptOwnOffer:
            return "不能接受自己的挂单"
        case .concurrencyConflict:
            return "该挂单已被其他人接受"
        case .invalidRating:
            return "评分必须在1-5之间"
        case .alreadyRated:
            return "您已经评价过这笔交易"
        case .databaseError(let msg):
            return "数据库错误: \(msg)"
        }
    }
}
