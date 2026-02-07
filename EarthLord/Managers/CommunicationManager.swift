//
//  CommunicationManager.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  通讯系统管理器
//

import Foundation
import Combine
import CoreLocation
import Supabase

@MainActor
final class CommunicationManager: ObservableObject {
    static let shared = CommunicationManager()

    // MARK: - 官方频道
    static let officialChannelId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    @Published private(set) var devices: [CommunicationDevice] = []
    @Published private(set) var currentDevice: CommunicationDevice?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Channel Properties
    @Published private(set) var channels: [CommunicationChannel] = []
    @Published private(set) var subscribedChannels: [SubscribedChannel] = []
    @Published private(set) var mySubscriptions: [ChannelSubscription] = []

    // MARK: - Message Properties
    @Published var channelMessages: [UUID: [ChannelMessage]] = [:]
    @Published var isSendingMessage = false

    // MARK: - Realtime Properties
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeSubscription: RealtimeSubscription?
    private var messageSubscriptionTask: Task<Void, Never>?
    @Published var subscribedChannelIds: Set<UUID> = []

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

    // MARK: - 消息加载

    /// 加载指定频道的最近 50 条消息
    func loadChannelMessages(channelId: UUID) async {
        do {
            let response: [ChannelMessage] = try await supabase
                .from("channel_messages")
                .select()
                .eq("channel_id", value: channelId.uuidString)
                .order("created_at", ascending: true)
                .limit(50)
                .execute()
                .value

            channelMessages[channelId] = response.filter { shouldReceiveMessage($0) }
        } catch {
            errorMessage = "加载消息失败: \(error.localizedDescription)"
        }
    }

    /// 发送频道消息（调用 RPC 函数）
    func sendChannelMessage(channelId: UUID, content: String, latitude: Double? = nil, longitude: Double? = nil, deviceType: String? = nil) async -> Bool {
        isSendingMessage = true
        defer { isSendingMessage = false }

        do {
            var params: [String: AnyJSON] = [
                "p_channel_id": .string(channelId.uuidString),
                "p_content": .string(content)
            ]
            if let lat = latitude {
                params["p_latitude"] = .double(lat)
            }
            if let lng = longitude {
                params["p_longitude"] = .double(lng)
            }
            if let dt = deviceType {
                params["p_device_type"] = .string(dt)
            }

            _ = try await supabase
                .rpc("send_channel_message", params: params)
                .execute()

            return true
        } catch {
            errorMessage = "发送消息失败: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Realtime 订阅

    /// 启动 Realtime 监听（监听 channel_messages 表的 INSERT）
    func startRealtimeSubscription() {
        guard realtimeChannel == nil else { return }

        let channel = supabase.realtimeV2.channel("channel_messages_realtime")

        realtimeSubscription = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "channel_messages"
        ) { [weak self] insertion in
            guard let self = self else { return }
            Task { @MainActor in
                await self.handleNewMessage(insertion: insertion)
            }
        }

        realtimeChannel = channel

        messageSubscriptionTask = Task {
            try? await channel.subscribeWithError()
        }
    }

    /// 停止 Realtime 监听
    func stopRealtimeSubscription() {
        messageSubscriptionTask?.cancel()
        messageSubscriptionTask = nil
        realtimeSubscription = nil

        if let channel = realtimeChannel {
            Task {
                await channel.unsubscribe()
            }
        }
        realtimeChannel = nil
    }

    /// 处理 Realtime 收到的新消息
    private func handleNewMessage(insertion: InsertAction) async {
        do {
            let decoder = JSONDecoder()
            let message = try insertion.decodeRecord(as: ChannelMessage.self, decoder: decoder)

            // 仅处理当前已订阅的频道消息
            guard subscribedChannelIds.contains(message.channelId) else { return }

            // 设备矩阵 + 距离过滤
            guard shouldReceiveMessage(message) else { return }

            var messages = channelMessages[message.channelId] ?? []
            messages.append(message)
            channelMessages[message.channelId] = messages
        } catch {
            print("⚠️ Realtime 消息解码失败: \(error)")
        }
    }

    /// 开始监听指定频道的消息（并确保 Realtime 已启动）
    func subscribeToChannelMessages(channelId: UUID) {
        subscribedChannelIds.insert(channelId)
        if realtimeChannel == nil {
            startRealtimeSubscription()
        }
    }

    /// 停止监听指定频道的消息
    func unsubscribeFromChannelMessages(channelId: UUID) {
        subscribedChannelIds.remove(channelId)
        channelMessages.removeValue(forKey: channelId)
        if subscribedChannelIds.isEmpty {
            stopRealtimeSubscription()
        }
    }

    /// 获取指定频道的消息列表
    func getMessages(for channelId: UUID) -> [ChannelMessage] {
        channelMessages[channelId] ?? []
    }

    // MARK: - 设备矩阵与距离过滤

    /// 将设备类型字符串转换为通讯范围（公里）
    private func deviceRangeKm(for deviceTypeString: String?) -> Double {
        guard let type = deviceTypeString, let deviceType = DeviceType(rawValue: type) else {
            return DeviceType.walkieTalkie.range
        }
        return deviceType.range
    }

    /// 判断是否应该对该频道应用距离过滤
    /// - official/publicChannel: 全局，不过滤
    /// - walkie/camp/satellite: 有距离限制，需要过滤
    private func shouldApplyDistanceFilter(for channelId: UUID) -> Bool {
        // 从已订阅频道中查找
        guard let subscribedChannel = subscribedChannels.first(where: { $0.channel.id == channelId }) else {
            return false  // 未知频道，不过滤（保守策略）
        }

        switch subscribedChannel.channel.channelType {
        case .official, .publicChannel:
            return false  // 官方/公共频道，全局范围
        case .walkie, .camp, .satellite:
            return true   // 对讲/营地/卫星频道，需要距离过滤
        }
    }

    /// 获取当前用户位置
    /// ⚠️ Day 35-A: 临时返回假数据，用于测试算法逻辑
    /// ⚠️ Day 35-B: 会替换为真实 GPS 位置
    private func getCurrentLocation() -> LocationPoint? {
        // TODO: Day 35-B 会替换为:
        // guard let location = LocationManager.shared.userLocation else { return nil }
        // return LocationPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)

        // 临时返回北京坐标（仅用于编译通过和逻辑测试）
        return LocationPoint(latitude: 39.9042, longitude: 116.4074)
    }

    /// 判断当前用户是否应该收到该消息（设备矩阵 + 距离过滤）
    /// - 有效通讯范围 = max(发送者设备范围, 接收者设备范围)
    /// - 任一方位置未知时容错允许接收
    func shouldReceiveMessage(_ message: ChannelMessage) -> Bool {
        // 1. 检查频道类型 — 只对特定频道应用距离过滤
        if !shouldApplyDistanceFilter(for: message.channelId) {
            print("📡 [距离过滤] 全局频道，跳过过滤")
            return true
        }

        // 2. 获取接收者设备范围
        let receiverRange = currentDevice?.deviceType.range ?? DeviceType.walkieTalkie.range

        // 3. 收音机可以接收所有消息（无限距离）
        if receiverRange == Double.infinity {
            print("📻 [距离过滤] 收音机用户，接收所有消息")
            return true
        }

        // 4. 获取发送者设备范围
        let senderRange = deviceRangeKm(for: message.deviceType)

        // 5. 收音机不能发送消息
        if senderRange == Double.infinity && message.deviceType == "radio" {
            print("🚫 [距离过滤] 收音机不能发送消息")
            return false
        }

        // 6. 计算有效范围（取较大值）
        let effectiveRangeKm = max(senderRange, receiverRange)

        // 7. 获取双方位置
        guard let senderLocation = message.senderLocation else {
            print("⚠️ [距离过滤] 消息缺少位置，保守显示")
            return true  // 保守策略
        }

        guard let myLocation = getCurrentLocation() else {
            print("⚠️ [距离过滤] 无法获取当前位置，保守显示")
            return true  // 保守策略
        }

        // 8. 计算距离
        let senderCLLocation = CLLocation(latitude: senderLocation.latitude, longitude: senderLocation.longitude)
        let myCLLocation = CLLocation(latitude: myLocation.latitude, longitude: myLocation.longitude)
        let distanceKm = myCLLocation.distance(from: senderCLLocation) / 1000.0

        // 9. 判断是否在范围内
        let canReceive = distanceKm <= effectiveRangeKm

        if canReceive {
            print("✅ [距离过滤] 通过: 距离=\(String(format: "%.1f", distanceKm))km, 范围=\(effectiveRangeKm)km")
        } else {
            print("🚫 [距离过滤] 丢弃: 距离=\(String(format: "%.1f", distanceKm))km, 范围=\(effectiveRangeKm)km")
        }

        return canReceive
    }

    // MARK: - 官方频道方法

    /// 判断是否为官方频道
    func isOfficialChannel(_ channelId: UUID) -> Bool {
        channelId == CommunicationManager.officialChannelId
    }

    /// 确保用户已订阅官方频道
    func ensureOfficialChannelSubscribed(userId: UUID) async {
        let officialId = CommunicationManager.officialChannelId

        // 检查是否已订阅
        if mySubscriptions.contains(where: { $0.channelId == officialId }) {
            return
        }

        // 尝试订阅
        do {
            let newSubscription = ChannelSubscriptionInsert(
                userId: userId.uuidString,
                channelId: officialId.uuidString
            )

            try await supabase
                .from("channel_subscriptions")
                .insert(newSubscription)
                .execute()

            // 刷新订阅列表
            await loadSubscribedChannels(userId: userId)
        } catch {
            // 忽略错误（可能已存在）
            print("⚠️ 官方频道订阅失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 消息中心聚合

    /// 频道摘要（用于消息中心列表）
    struct ChannelSummary: Identifiable {
        let channel: CommunicationChannel
        let latestMessage: ChannelMessage?
        let unreadCount: Int

        var id: UUID { channel.id }
    }

    /// 获取频道摘要列表（官方频道置顶）
    func getChannelSummaries() -> [ChannelSummary] {
        var summaries: [ChannelSummary] = []

        for subscribedChannel in subscribedChannels {
            let messages = channelMessages[subscribedChannel.channel.id] ?? []
            let latestMessage = messages.last
            let summary = ChannelSummary(
                channel: subscribedChannel.channel,
                latestMessage: latestMessage,
                unreadCount: 0  // TODO: 实现未读计数
            )
            summaries.append(summary)
        }

        // 官方频道置顶
        summaries.sort { lhs, rhs in
            if isOfficialChannel(lhs.channel.id) { return true }
            if isOfficialChannel(rhs.channel.id) { return false }
            // 其他按最新消息时间排序
            let lhsTime = lhs.latestMessage?.createdAt ?? lhs.channel.createdAt
            let rhsTime = rhs.latestMessage?.createdAt ?? rhs.channel.createdAt
            return lhsTime > rhsTime
        }

        return summaries
    }

    /// 加载所有订阅频道的最新消息
    func loadAllChannelLatestMessages() async {
        for subscribedChannel in subscribedChannels {
            await loadChannelMessages(channelId: subscribedChannel.channel.id)
        }
    }

    // MARK: - 用户呼号

    /// 加载用户呼号
    func loadUserCallsign(userId: UUID) async -> String? {
        do {
            let response: [UserProfileRow] = try await supabase
                .from("user_profiles")
                .select("callsign")
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            return response.first?.callsign
        } catch {
            print("⚠️ 加载呼号失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 保存用户呼号
    func saveUserCallsign(userId: UUID, callsign: String) async -> Bool {
        do {
            // 尝试 upsert
            let profile = UserProfileUpsert(userId: userId.uuidString, callsign: callsign)
            try await supabase
                .from("user_profiles")
                .upsert(profile, onConflict: "user_id")
                .execute()
            return true
        } catch {
            errorMessage = "保存呼号失败: \(error.localizedDescription)"
            return false
        }
    }
}

// MARK: - User Profile Models

private struct UserProfileRow: Decodable {
    let callsign: String?
}

private struct UserProfileUpsert: Encodable {
    let userId: String
    let callsign: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case callsign
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
