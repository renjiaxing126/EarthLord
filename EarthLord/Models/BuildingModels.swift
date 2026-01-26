//
//  BuildingModels.swift
//  EarthLord
//
//  Created by Claude on 2026/1/26.
//  建造系统数据模型
//

import Foundation
import SwiftUI

// MARK: - BuildingCategory 建筑类别

/// 建筑类别枚举
enum BuildingCategory: String, Codable, CaseIterable {
    case survival = "survival"       // 生存
    case storage = "storage"         // 储存
    case production = "production"   // 生产
    case energy = "energy"           // 能源

    var displayName: String {
        switch self {
        case .survival: return "生存"
        case .storage: return "储存"
        case .production: return "生产"
        case .energy: return "能源"
        }
    }

    var icon: String {
        switch self {
        case .survival: return "house.fill"
        case .storage: return "archivebox.fill"
        case .production: return "hammer.fill"
        case .energy: return "bolt.fill"
        }
    }
}

// MARK: - BuildingStatus 建筑状态

/// 建筑状态枚举
enum BuildingStatus: String, Codable {
    case constructing = "constructing"  // 建造中
    case active = "active"              // 运行中

    var displayName: String {
        switch self {
        case .constructing: return "建造中"
        case .active: return "运行中"
        }
    }

    var color: Color {
        switch self {
        case .constructing: return .blue
        case .active: return .green
        }
    }
}

// MARK: - BuildingTemplate 建筑模板

/// 建筑模板结构体（从 JSON 加载）
struct BuildingTemplate: Codable, Identifiable {
    let id: UUID
    let templateId: String
    let name: String
    let tier: Int
    let category: BuildingCategory
    let description: String
    let icon: String
    let requiredResources: [String: Int]
    let buildTimeSeconds: Int
    let maxPerTerritory: Int
    let maxLevel: Int

    enum CodingKeys: String, CodingKey {
        case id
        case templateId = "template_id"
        case name
        case tier
        case category
        case description
        case icon
        case requiredResources = "required_resources"
        case buildTimeSeconds = "build_time_seconds"
        case maxPerTerritory = "max_per_territory"
        case maxLevel = "max_level"
    }
}

// MARK: - PlayerBuilding 玩家建筑

/// 玩家建筑结构体（数据库表映射）
struct PlayerBuilding: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let territoryId: String
    let templateId: String
    let buildingName: String
    var status: BuildingStatus
    var level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: Date
    var buildCompletedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status
        case level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - 计算属性

    /// 计算建造进度（0-1）
    /// 需要传入模板的建造时间
    func buildProgress(buildTimeSeconds: Int) -> Double {
        guard status == .constructing else { return 1.0 }

        let elapsed = Date().timeIntervalSince(buildStartedAt)
        let total = Double(buildTimeSeconds)
        return min(1.0, elapsed / total)
    }

    /// 获取剩余建造时间（秒）
    func remainingBuildTime(buildTimeSeconds: Int) -> TimeInterval {
        guard status == .constructing else { return 0 }

        let elapsed = Date().timeIntervalSince(buildStartedAt)
        return max(0, Double(buildTimeSeconds) - elapsed)
    }

    /// 格式化剩余时间
    func formattedRemainingTime(buildTimeSeconds: Int) -> String {
        let remaining = remainingBuildTime(buildTimeSeconds: buildTimeSeconds)

        if remaining <= 0 {
            return "即将完成"
        } else if remaining < 60 {
            return "\(Int(remaining))秒"
        } else if remaining < 3600 {
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            return "\(minutes)分\(seconds)秒"
        } else {
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            return "\(hours)小时\(minutes)分"
        }
    }
}

// MARK: - InsertPlayerBuilding 插入用模型

/// 用于插入新建筑的模型
struct InsertPlayerBuilding: Codable {
    let userId: String
    let territoryId: String
    let templateId: String
    let buildingName: String
    let status: String
    let level: Int
    let locationLat: Double?
    let locationLon: Double?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status
        case level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
    }
}

// MARK: - UpdatePlayerBuilding 更新用模型

/// 用于更新建筑的模型
struct UpdatePlayerBuilding: Codable {
    let status: String?
    let level: Int?
    let buildCompletedAt: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case status
        case level
        case buildCompletedAt = "build_completed_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - BuildingError 建筑错误

/// 建筑相关错误枚举
enum BuildingError: Error, LocalizedError {
    case insufficientResources([String: Int])
    case maxBuildingsReached(Int)
    case templateNotFound
    case invalidStatus
    case maxLevelReached
    case databaseError(String)
    case userNotLoggedIn

    var errorDescription: String? {
        switch self {
        case .insufficientResources(let missing):
            let items = missing.map { "\($0.key): 缺少\($0.value)" }.joined(separator: ", ")
            return "资源不足: \(items)"
        case .maxBuildingsReached(let max):
            return "该建筑已达上限(\(max)个)"
        case .templateNotFound:
            return "建筑模板不存在"
        case .invalidStatus:
            return "只能升级运行中的建筑"
        case .maxLevelReached:
            return "已达最高等级"
        case .databaseError(let msg):
            return "数据库错误: \(msg)"
        case .userNotLoggedIn:
            return "用户未登录"
        }
    }
}
