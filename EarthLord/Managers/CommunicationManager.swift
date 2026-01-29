//
//  CommunicationManager.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  通讯系统管理器
//

import Foundation
import Combine
import Supabase

@MainActor
final class CommunicationManager: ObservableObject {
    static let shared = CommunicationManager()

    @Published private(set) var devices: [CommunicationDevice] = []
    @Published private(set) var currentDevice: CommunicationDevice?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Channel Properties
    @Published private(set) var channels: [CommunicationChannel] = []
    @Published private(set) var subscribedChannels: [SubscribedChannel] = []
    @Published private(set) var mySubscriptions: [ChannelSubscription] = []

    private let supabase = SupabaseService.shared

    private init() {}

    // MARK: - 加载设备

    func loadDevices(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [CommunicationDevice] = try await supabase
                .from("communication_devices")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            devices = response
            currentDevice = devices.first(where: { $0.isCurrent })

            if devices.isEmpty {
                await initializeDevices(userId: userId)
            }
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 初始化设备

    func initializeDevices(userId: UUID) async {
        do {
            try await supabase.rpc("initialize_user_devices", params: ["p_user_id": userId.uuidString]).execute()
            await loadDevices(userId: userId)
        } catch {
            errorMessage = "初始化失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 切换设备

    func switchDevice(userId: UUID, to deviceType: DeviceType) async {
        guard let device = devices.first(where: { $0.deviceType == deviceType }),
              device.isUnlocked else {
            errorMessage = "设备未解锁"
            return
        }

        if device.isCurrent { return }

        isLoading = true

        do {
            try await supabase.rpc("switch_current_device", params: [
                "p_user_id": userId.uuidString,
                "p_device_type": deviceType.rawValue
            ]).execute()

            for i in devices.indices {
                devices[i].isCurrent = (devices[i].deviceType == deviceType)
            }
            currentDevice = devices.first(where: { $0.deviceType == deviceType })
        } catch {
            errorMessage = "切换失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 解锁设备（由建造系统调用）

    func unlockDevice(userId: UUID, deviceType: DeviceType) async {
        do {
            let updateData = DeviceUnlockUpdate(
                isUnlocked: true,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )

            try await supabase
                .from("communication_devices")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .eq("device_type", value: deviceType.rawValue)
                .execute()

            if let index = devices.firstIndex(where: { $0.deviceType == deviceType }) {
                devices[index].isUnlocked = true
            }
        } catch {
            errorMessage = "解锁失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 便捷方法

    func getCurrentDeviceType() -> DeviceType {
        currentDevice?.deviceType ?? .walkieTalkie
    }

    func canSendMessage() -> Bool {
        currentDevice?.deviceType.canSend ?? false
    }

    func getCurrentRange() -> Double {
        currentDevice?.deviceType.range ?? 3.0
    }

    func isDeviceUnlocked(_ deviceType: DeviceType) -> Bool {
        devices.first(where: { $0.deviceType == deviceType })?.isUnlocked ?? false
    }

    // MARK: - Channel Methods

    /// 加载所有公开频道
    func loadPublicChannels() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [CommunicationChannel] = try await supabase
                .from("communication_channels")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            channels = response
        } catch {
            errorMessage = "加载频道失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 加载用户订阅的频道
    func loadSubscribedChannels(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            // 加载订阅关系
            let subscriptions: [ChannelSubscription] = try await supabase
                .from("channel_subscriptions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            mySubscriptions = subscriptions

            // 如果有订阅，加载对应的频道信息
            if !subscriptions.isEmpty {
                let channelIds = subscriptions.map { $0.channelId.uuidString }
                let subscribedChannelsList: [CommunicationChannel] = try await supabase
                    .from("communication_channels")
                    .select()
                    .in("id", values: channelIds)
                    .execute()
                    .value

                // 组合订阅频道数据
                subscribedChannels = subscriptions.compactMap { sub in
                    guard let channel = subscribedChannelsList.first(where: { $0.id == sub.channelId }) else {
                        return nil
                    }
                    return SubscribedChannel(channel: channel, subscription: sub)
                }
            } else {
                subscribedChannels = []
            }
        } catch {
            errorMessage = "加载订阅失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 创建频道
    func createChannel(userId: UUID, type: ChannelType, name: String, description: String?) async throws -> UUID {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let params: [String: AnyJSON] = [
                "p_creator_id": .string(userId.uuidString),
                "p_channel_type": .string(type.rawValue),
                "p_name": .string(name),
                "p_description": description.map { .string($0) } ?? .null
            ]

            let response: AnyJSON = try await supabase
                .rpc("create_channel_with_subscription", params: params)
                .execute()
                .value

            // 解析返回的 UUID
            guard case let .string(channelIdString) = response,
                  let channelId = UUID(uuidString: channelIdString) else {
                throw NSError(domain: "CommunicationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析频道ID"])
            }

            // 刷新频道列表
            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)

            return channelId
        } catch {
            errorMessage = "创建频道失败: \(error.localizedDescription)"
            throw error
        }
    }

    /// 订阅频道
    func subscribeToChannel(userId: UUID, channelId: UUID) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let newSubscription = ChannelSubscriptionInsert(
                userId: userId.uuidString,
                channelId: channelId.uuidString
            )

            try await supabase
                .from("channel_subscriptions")
                .insert(newSubscription)
                .execute()

            // 更新频道成员数
            if let channel = channels.first(where: { $0.id == channelId }) {
                try await supabase
                    .from("communication_channels")
                    .update(["member_count": channel.memberCount + 1])
                    .eq("id", value: channelId.uuidString)
                    .execute()
            }

            // 刷新订阅列表
            await loadSubscribedChannels(userId: userId)
            await loadPublicChannels()
        } catch {
            errorMessage = "订阅失败: \(error.localizedDescription)"
            throw error
        }
    }

    /// 取消订阅频道
    func unsubscribeFromChannel(userId: UUID, channelId: UUID) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await supabase
                .from("channel_subscriptions")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("channel_id", value: channelId.uuidString)
                .execute()

            // 更新频道成员数
            if let channel = channels.first(where: { $0.id == channelId }) {
                try await supabase
                    .from("communication_channels")
                    .update(["member_count": max(0, channel.memberCount - 1)])
                    .eq("id", value: channelId.uuidString)
                    .execute()
            }

            // 刷新订阅列表
            await loadSubscribedChannels(userId: userId)
            await loadPublicChannels()
        } catch {
            errorMessage = "取消订阅失败: \(error.localizedDescription)"
            throw error
        }
    }

    /// 删除频道（仅创建者可用）
    func deleteChannel(channelId: UUID) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await supabase
                .from("communication_channels")
                .delete()
                .eq("id", value: channelId.uuidString)
                .execute()

            // 刷新频道列表
            await loadPublicChannels()
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
            throw error
        }
    }

    /// 检查是否已订阅
    func isSubscribed(channelId: UUID) -> Bool {
        mySubscriptions.contains { $0.channelId == channelId }
    }
}

// MARK: - Insert Models

private struct ChannelSubscriptionInsert: Encodable {
    let userId: String
    let channelId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case channelId = "channel_id"
    }
}

// MARK: - Update Models

private struct DeviceUnlockUpdate: Encodable {
    let isUnlocked: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case isUnlocked = "is_unlocked"
        case updatedAt = "updated_at"
    }
}
