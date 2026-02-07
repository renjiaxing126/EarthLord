//
//  CommunicationModels.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  通讯系统数据模型
//

import Foundation
import SwiftUI

// MARK: - 消息分类（官方频道）
enum MessageCategory: String, Codable, CaseIterable {
    case survival = "survival"
    case news = "news"
    case mission = "mission"
    case alert = "alert"

    var displayName: String {
        switch self {
        case .survival: return "生存指南"
        case .news: return "游戏资讯"
        case .mission: return "任务公告"
        case .alert: return "紧急广播"
        }
    }

    var color: Color {
        switch self {
        case .survival: return ApocalypseTheme.success
        case .news: return ApocalypseTheme.info
        case .mission: return ApocalypseTheme.warning
        case .alert: return ApocalypseTheme.danger
        }
    }

    var iconName: String {
        switch self {
        case .survival: return "leaf.fill"
        case .news: return "newspaper.fill"
        case .mission: return "flag.fill"
        case .alert: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - 设备类型
enum DeviceType: String, Codable, CaseIterable {
    case radio = "radio"
    case walkieTalkie = "walkie_talkie"
    case campRadio = "camp_radio"
    case satellite = "satellite"

    var displayName: String {
        switch self {
        case .radio: return "收音机"
        case .walkieTalkie: return "对讲机"
        case .campRadio: return "营地电台"
        case .satellite: return "卫星通讯"
        }
    }

    var iconName: String {
        switch self {
        case .radio: return "radio"
        case .walkieTalkie: return "walkie.talkie.radio"
        case .campRadio: return "antenna.radiowaves.left.and.right"
        case .satellite: return "antenna.radiowaves.left.and.right.circle"
        }
    }

    var description: String {
        switch self {
        case .radio: return "只能接收信号，无法发送消息"
        case .walkieTalkie: return "可在3公里范围内通讯"
        case .campRadio: return "可在30公里范围内广播"
        case .satellite: return "可在100公里+范围内联络"
        }
    }

    var range: Double {
        switch self {
        case .radio: return Double.infinity
        case .walkieTalkie: return 3.0
        case .campRadio: return 30.0
        case .satellite: return 100.0
        }
    }

    var rangeText: String {
        switch self {
        case .radio: return "无限制（仅接收）"
        case .walkieTalkie: return "3 公里"
        case .campRadio: return "30 公里"
        case .satellite: return "100+ 公里"
        }
    }

    var canSend: Bool {
        self != .radio
    }

    var unlockRequirement: String {
        switch self {
        case .radio, .walkieTalkie: return "默认拥有"
        case .campRadio: return "需建造「营地电台」建筑"
        case .satellite: return "需建造「通讯塔」建筑"
        }
    }
}

// MARK: - 设备模型
struct CommunicationDevice: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let deviceType: DeviceType
    var deviceLevel: Int
    var isUnlocked: Bool
    var isCurrent: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceType = "device_type"
        case deviceLevel = "device_level"
        case isUnlocked = "is_unlocked"
        case isCurrent = "is_current"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 导航枚举
enum CommunicationSection: String, CaseIterable {
    case messages = "消息"
    case channels = "频道"
    case call = "呼叫"
    case devices = "设备"

    var iconName: String {
        switch self {
        case .messages: return "bell.fill"
        case .channels: return "dot.radiowaves.left.and.right"
        case .call: return "phone.fill"
        case .devices: return "gearshape.fill"
        }
    }
}

// MARK: - 频道类型
enum ChannelType: String, Codable, CaseIterable {
    case official = "official"
    case publicChannel = "public"
    case walkie = "walkie"
    case camp = "camp"
    case satellite = "satellite"

    var displayName: String {
        switch self {
        case .official: return "官方频道"
        case .publicChannel: return "公共频道"
        case .walkie: return "对讲频道"
        case .camp: return "营地频道"
        case .satellite: return "卫星频道"
        }
    }

    var iconName: String {
        switch self {
        case .official: return "building.2.fill"
        case .publicChannel: return "globe"
        case .walkie: return "walkie.talkie.radio"
        case .camp: return "antenna.radiowaves.left.and.right"
        case .satellite: return "antenna.radiowaves.left.and.right.circle"
        }
    }

    var description: String {
        switch self {
        case .official: return "官方发布的公告和重要信息"
        case .publicChannel: return "任何人都可以加入的公开频道"
        case .walkie: return "需要对讲机，范围3公里"
        case .camp: return "需要营地电台，范围30公里"
        case .satellite: return "需要卫星通讯，范围100+公里"
        }
    }

    var rangeText: String {
        switch self {
        case .official: return "全局"
        case .publicChannel: return "全局"
        case .walkie: return "3 公里"
        case .camp: return "30 公里"
        case .satellite: return "100+ 公里"
        }
    }

    /// 用户可创建的频道类型
    static var creatableTypes: [ChannelType] {
        [.publicChannel, .walkie, .camp, .satellite]
    }
}

// MARK: - 频道模型
struct CommunicationChannel: Codable, Identifiable, Hashable {
    let id: UUID
    let creatorId: UUID?  // 官方频道无创建者
    let channelType: ChannelType
    let channelCode: String
    let name: String
    let description: String?
    let isActive: Bool
    let memberCount: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case channelType = "channel_type"
        case channelCode = "channel_code"
        case name
        case description
        case isActive = "is_active"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Hashable（仅基于 id）
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CommunicationChannel, rhs: CommunicationChannel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 订阅模型
struct ChannelSubscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let channelId: UUID
    let isMuted: Bool
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case channelId = "channel_id"
        case isMuted = "is_muted"
        case joinedAt = "joined_at"
    }
}

// MARK: - 已订阅频道（组合模型）
struct SubscribedChannel: Identifiable {
    let channel: CommunicationChannel
    let subscription: ChannelSubscription

    var id: UUID { channel.id }
}

// MARK: - 消息位置点
struct LocationPoint: Codable {
    let latitude: Double
    let longitude: Double

    /// 从 PostGIS WKT 格式解析位置，例如 "POINT(经度 纬度)"
    static func fromPostGIS(_ wkt: String) -> LocationPoint? {
        // 匹配 POINT(lon lat) 或 SRID=4326;POINT(lon lat)
        let pattern = #"POINT\s*\(\s*([-+]?\d*\.?\d+)\s+([-+]?\d*\.?\d+)\s*\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: wkt, range: NSRange(wkt.startIndex..., in: wkt)),
              let lonRange = Range(match.range(at: 1), in: wkt),
              let latRange = Range(match.range(at: 2), in: wkt),
              let longitude = Double(wkt[lonRange]),
              let latitude = Double(wkt[latRange]) else {
            return nil
        }
        return LocationPoint(latitude: latitude, longitude: longitude)
    }
}

// MARK: - 消息元数据
struct MessageMetadata: Codable {
    let deviceType: String?
    let category: String?  // 消息分类（官方频道使用）

    enum CodingKeys: String, CodingKey {
        case deviceType = "device_type"
        case category
    }
}

// MARK: - 频道消息
struct ChannelMessage: Identifiable, Decodable {
    let messageId: UUID
    let channelId: UUID
    let senderId: UUID?
    let senderCallsign: String?
    let content: String
    let senderLocation: LocationPoint?
    let metadata: MessageMetadata?
    let createdAt: Date

    var id: UUID { messageId }

    /// 设备类型（从 metadata 提取）
    var deviceType: String? {
        metadata?.deviceType
    }

    /// 消息分类（从 metadata 提取，用于官方频道）
    var category: MessageCategory? {
        guard let categoryString = metadata?.category else { return nil }
        return MessageCategory(rawValue: categoryString)
    }

    /// 人类可读的时间差
    var timeAgo: String {
        let now = Date()
        let diff = now.timeIntervalSince(createdAt)
        if diff < 60 {
            return "刚刚"
        } else if diff < 3600 {
            let minutes = Int(diff / 60)
            return "\(minutes)分钟前"
        } else if diff < 86400 {
            let hours = Int(diff / 3600)
            return "\(hours)小时前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: createdAt)
        }
    }

    // MARK: - 自定义解码

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        messageId = try container.decode(UUID.self, forKey: .messageId)
        channelId = try container.decode(UUID.self, forKey: .channelId)
        senderId = try container.decodeIfPresent(UUID.self, forKey: .senderId)
        senderCallsign = try container.decodeIfPresent(String.self, forKey: .senderCallsign)
        content = try container.decode(String.self, forKey: .content)
        metadata = try container.decodeIfPresent(MessageMetadata.self, forKey: .metadata)

        // senderLocation: 先尝试 String (PostGIS WKT)，失败则直接解码为 LocationPoint
        if let wktString = try? container.decode(String.self, forKey: .senderLocation) {
            senderLocation = LocationPoint.fromPostGIS(wktString)
        } else {
            senderLocation = try container.decodeIfPresent(LocationPoint.self, forKey: .senderLocation)
        }

        // createdAt: 先尝试 String 多格式解析，失败则直接解码为 Date
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            guard let parsed = ChannelMessage.parseDate(dateString) else {
                throw DecodingError.dataCorruptedError(forKey: .createdAt, in: container, debugDescription: "无法解析日期: \(dateString)")
            }
            createdAt = parsed
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
    }

    /// 支持多种日期格式
    private static func parseDate(_ string: String) -> Date? {
        let formatters: [DateFormatter] = {
            let iso = DateFormatter()
            iso.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSX"
            iso.locale = Locale(identifier: "en_US_POSIX")
            iso.timeZone = TimeZone(identifier: "UTC")

            let isoShort = DateFormatter()
            isoShort.dateFormat = "yyyy-MM-dd'T'HH:mm:ssX"
            isoShort.locale = Locale(identifier: "en_US_POSIX")
            isoShort.timeZone = TimeZone(identifier: "UTC")

            let isoZ = DateFormatter()
            isoZ.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            isoZ.locale = Locale(identifier: "en_US_POSIX")
            isoZ.timeZone = TimeZone(identifier: "UTC")

            let plain = DateFormatter()
            plain.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            plain.locale = Locale(identifier: "en_US_POSIX")
            plain.timeZone = TimeZone(identifier: "UTC")

            return [iso, isoShort, isoZ, plain]
        }()

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        // 兜底：ISO8601DateFormatter
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601.date(from: string) {
            return date
        }
        iso8601.formatOptions = [.withInternetDateTime]
        return iso8601.date(from: string)
    }

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case channelId = "channel_id"
        case senderId = "sender_id"
        case senderCallsign = "sender_callsign"
        case content
        case senderLocation = "sender_location"
        case metadata
        case createdAt = "created_at"
    }
}
