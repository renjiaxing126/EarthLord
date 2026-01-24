//
//  PlayerLocationManager.swift
//  EarthLord
//
//  Created by Claude on 2026/1/16.
//  玩家位置管理器 - 负责位置上报和附近玩家密度检测
//

import Foundation
import CoreLocation
import Combine
import os.log
import Supabase

/// 玩家位置日志器
private let playerLocationLog = OSLog(subsystem: "com.yanshuangren.EarthLord", category: "PlayerLocation")

/// 玩家密度等级
enum PlayerDensityLevel: String, CaseIterable {
    case lone = "独行者"      // 0人
    case low = "低密度"       // 1-5人
    case medium = "中密度"    // 6-20人
    case high = "高密度"      // 20+人

    /// 该密度等级对应的最大POI显示数量
    /// 注意：即使是独行者也应该有足够的POI可探索
    var maxPOICount: Int {
        switch self {
        case .lone: return 10    // 独自探索也有丰富的POI
        case .low: return 15     // 低密度区域
        case .medium: return 20  // 中密度区域
        case .high: return 25    // 高密度区域更多选择
        }
    }

    /// 密度等级图标
    var icon: String {
        switch self {
        case .lone: return "person"
        case .low: return "person.2"
        case .medium: return "person.3"
        case .high: return "person.3.sequence"
        }
    }
}

// MARK: - RPC Helper Actor

/// 独立的RPC执行器，避免MainActor隔离问题
private actor RPCExecutor {
    private let supabase: SupabaseClient

    // 在actor内部定义参数结构体，确保与actor同一隔离域
    private struct UpsertParams: Encodable, Sendable {
        let p_user_id: String
        let p_latitude: Double
        let p_longitude: Double
    }

    private struct NearbyParams: Encodable, Sendable {
        let p_user_id: String
        let p_latitude: Double
        let p_longitude: Double
        let p_radius_meters: Double
    }

    private struct OfflineParams: Encodable, Sendable {
        let p_user_id: String
    }

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    func upsertLocation(userId: String, latitude: Double, longitude: Double) async throws {
        let params = UpsertParams(p_user_id: userId, p_latitude: latitude, p_longitude: longitude)
        try await supabase.rpc("upsert_player_location", params: params).execute()
    }

    func countNearbyPlayers(userId: String, latitude: Double, longitude: Double, radiusMeters: Double) async throws -> Int {
        let params = NearbyParams(p_user_id: userId, p_latitude: latitude, p_longitude: longitude, p_radius_meters: radiusMeters)
        return try await supabase.rpc("count_nearby_players", params: params).execute().value
    }

    func markOffline(userId: String) async throws {
        let params = OfflineParams(p_user_id: userId)
        try await supabase.rpc("mark_player_offline", params: params).execute()
    }
}

/// 玩家位置管理器
/// 负责位置上报、附近玩家查询、密度计算
@MainActor
class PlayerLocationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = PlayerLocationManager()

    // MARK: - Published Properties

    /// 附近玩家数量
    @Published var nearbyPlayerCount: Int = 0

    /// 当前密度等级
    @Published var densityLevel: PlayerDensityLevel = .lone

    /// 是否正在上报
    @Published var isReporting: Bool = false

    /// 最后上报时间
    @Published var lastReportTime: Date?

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    /// Supabase客户端
    private let supabase = SupabaseService.shared

    /// RPC执行器（独立actor，避免MainActor隔离问题）
    private let rpcExecutor: RPCExecutor

    /// 位置管理器
    private let locationManager = LocationManager.shared

    /// 定时上报计时器
    private var reportTimer: Timer?

    /// 最后上报的位置
    private var lastReportedLocation: CLLocation?

    /// 位置订阅
    private var locationCancellable: AnyCancellable?

    // MARK: - Constants

    /// 上报间隔（秒）
    private let reportInterval: TimeInterval = 30.0

    /// 移动触发阈值（米）- 超过此距离立即上报
    private let movementThreshold: Double = 50.0

    /// 查询半径（米）
    private let queryRadius: Double = 1000.0

    // MARK: - Initialization

    private init() {
        self.rpcExecutor = RPCExecutor(supabase: SupabaseService.shared)
        print("📍 [PlayerLocationManager] 初始化完成")
        os_log("📍 PlayerLocationManager初始化", log: playerLocationLog, type: .info)
    }

    // MARK: - Public Methods

    /// 上报当前位置
    /// - Parameter location: 要上报的位置
    func reportLocation(_ location: CLLocation) async {
        isReporting = true

        print("📤 [PlayerLocationManager] 上报位置到数据库...")
        print("   - 坐标: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        os_log("📤 上报位置: (%{public}.6f, %{public}.6f)",
               log: playerLocationLog, type: .info,
               location.coordinate.latitude, location.coordinate.longitude)

        do {
            let user = try await supabase.auth.user()
            print("   - 用户ID: \(user.id.uuidString.prefix(8))...")

            // 使用独立actor执行RPC调用，避免MainActor隔离问题
            print("📡 [PlayerLocationManager] 调用 upsert_player_location RPC...")
            try await rpcExecutor.upsertLocation(
                userId: user.id.uuidString,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )

            lastReportedLocation = location
            lastReportTime = Date()
            errorMessage = nil

            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            print("✅ [PlayerLocationManager] 位置上报成功 @ \(formatter.string(from: Date()))")
            os_log("✅ 位置上报成功", log: playerLocationLog, type: .info)

        } catch {
            errorMessage = "位置上报失败: \(error.localizedDescription)"
            print("❌ [PlayerLocationManager] 位置上报失败: \(error)")
            os_log("❌ 位置上报失败: %{public}@",
                   log: playerLocationLog, type: .error, error.localizedDescription)
        }

        isReporting = false
    }

    /// 查询附近玩家数量
    /// - Parameter location: 查询中心位置
    /// - Returns: 附近玩家数量
    func queryNearbyPlayers(at location: CLLocation) async -> Int {
        print("═══════════════════════════════════════════════════")
        print("🔍 [PlayerLocationManager] 开始查询附近玩家")
        print("   - 查询中心: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        print("   - 查询半径: \(Int(queryRadius)) 米")
        print("═══════════════════════════════════════════════════")
        os_log("🔍 查询附近玩家: (%{public}.6f, %{public}.6f) 半径%{public}.0fm",
               log: playerLocationLog, type: .info,
               location.coordinate.latitude, location.coordinate.longitude, queryRadius)

        do {
            let user = try await supabase.auth.user()
            print("👤 [PlayerLocationManager] 当前用户ID: \(user.id.uuidString.prefix(8))...")

            // 使用独立actor执行RPC调用，避免MainActor隔离问题
            print("📡 [PlayerLocationManager] 调用 count_nearby_players RPC...")
            let response = try await rpcExecutor.countNearbyPlayers(
                userId: user.id.uuidString,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radiusMeters: queryRadius
            )

            nearbyPlayerCount = response
            densityLevel = calculateDensityLevel(playerCount: response)

            print("═══════════════════════════════════════════════════")
            print("✅ [PlayerLocationManager] 查询结果:")
            print("   - 附近玩家数量: \(response) 人 (不含自己)")
            print("   - 密度等级: \(densityLevel.rawValue)")
            print("   - 推荐POI数量: \(densityLevel.maxPOICount) 个")
            print("═══════════════════════════════════════════════════")
            os_log("✅ 附近玩家: %{public}d人, 密度: %{public}@",
                   log: playerLocationLog, type: .info, response, densityLevel.rawValue)

            return response

        } catch {
            print("═══════════════════════════════════════════════════")
            print("❌ [PlayerLocationManager] 查询附近玩家失败!")
            print("   - 错误: \(error)")
            print("   - 使用默认值: 0人 (独行者模式)")
            print("═══════════════════════════════════════════════════")
            os_log("❌ 查询附近玩家失败: %{public}@",
                   log: playerLocationLog, type: .error, error.localizedDescription)

            // 查询失败时返回0，使用最保守的策略
            nearbyPlayerCount = 0
            densityLevel = .lone
            return 0
        }
    }

    /// 根据玩家数量计算密度等级
    /// - Parameter playerCount: 附近玩家数量
    /// - Returns: 密度等级
    func calculateDensityLevel(playerCount: Int) -> PlayerDensityLevel {
        switch playerCount {
        case 0:
            return .lone
        case 1...5:
            return .low
        case 6...20:
            return .medium
        default:
            return .high
        }
    }

    /// 上报计数器（用于控制查询频率）
    private var reportCount: Int = 0

    /// 启动定时上报（探索开始时调用）
    func startPeriodicReporting() {
        // 先停止已有的定时器
        stopPeriodicReporting()
        reportCount = 0

        print("═══════════════════════════════════════════════════")
        print("⏱️ [PlayerLocationManager] 启动定时上报")
        print("   - 上报间隔: \(Int(reportInterval)) 秒")
        print("   - 查询半径: \(Int(queryRadius)) 米")
        print("   - 当前密度: \(densityLevel.rawValue) (\(nearbyPlayerCount)人)")
        print("═══════════════════════════════════════════════════")
        os_log("⏱️ 启动定时上报", log: playerLocationLog, type: .info)

        // 立即上报一次并查询附近玩家
        if let location = locationManager.userLocation {
            Task {
                await reportLocationAndQueryNearby(location)
            }
        }

        // 启动定时器
        reportTimer = Timer.scheduledTimer(withTimeInterval: reportInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if let location = self.locationManager.userLocation {
                    await self.reportLocationAndQueryNearby(location)
                }
            }
        }

        // 订阅位置更新，检测大幅移动
        subscribeToLocationUpdates()
    }

    /// 上报位置并查询附近玩家（定时调用）
    private func reportLocationAndQueryNearby(_ location: CLLocation) async {
        reportCount += 1

        // 先上报位置
        await reportLocation(location)

        // 每次上报都查询附近玩家（保持信息同步）
        _ = await queryNearbyPlayers(at: location)

        // 打印当前状态摘要
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        print("📊 [PlayerLocationManager] 状态摘要 @ \(formatter.string(from: Date()))")
        print("   - 第 \(reportCount) 次上报")
        print("   - 附近玩家: \(nearbyPlayerCount) 人")
        print("   - 密度等级: \(densityLevel.rawValue)")
        print("   - POI上限: \(densityLevel.maxPOICount) 个")
    }

    /// 停止定时上报（探索结束时调用）
    func stopPeriodicReporting() {
        reportTimer?.invalidate()
        reportTimer = nil
        locationCancellable?.cancel()
        locationCancellable = nil

        print("═══════════════════════════════════════════════════")
        print("⏹️ [PlayerLocationManager] 停止定时上报")
        print("   - 本次共上报: \(reportCount) 次")
        print("   - 最后密度: \(densityLevel.rawValue) (\(nearbyPlayerCount)人)")
        print("═══════════════════════════════════════════════════")
        os_log("⏹️ 停止定时上报", log: playerLocationLog, type: .info)

        reportCount = 0
    }

    /// 标记玩家离线（App进入后台时调用）
    func markOffline() async {
        print("🔴 [PlayerLocationManager] 标记离线")
        os_log("🔴 标记离线", log: playerLocationLog, type: .info)

        do {
            let user = try await supabase.auth.user()

            // 使用独立actor执行RPC调用，避免MainActor隔离问题
            try await rpcExecutor.markOffline(userId: user.id.uuidString)

            print("✅ [PlayerLocationManager] 已标记为离线")
            os_log("✅ 已标记为离线", log: playerLocationLog, type: .info)

        } catch {
            print("❌ [PlayerLocationManager] 标记离线失败: \(error)")
            os_log("❌ 标记离线失败: %{public}@",
                   log: playerLocationLog, type: .error, error.localizedDescription)
        }
    }

    /// 获取密度等级对应的POI数量
    /// - Returns: 建议显示的POI数量
    func getRecommendedPOICount() -> Int {
        return densityLevel.maxPOICount
    }

    // MARK: - Private Methods

    /// 订阅位置更新，检测大幅移动时立即上报
    private func subscribeToLocationUpdates() {
        locationCancellable = locationManager.$userLocation
            .compactMap { $0 }
            .sink { [weak self] newLocation in
                guard let self = self else { return }

                // 检查是否移动超过阈值
                if let lastLocation = self.lastReportedLocation {
                    let distance = newLocation.distance(from: lastLocation)
                    if distance >= self.movementThreshold {
                        print("📍 [PlayerLocationManager] 移动超过\(Int(self.movementThreshold))米，立即上报")
                        os_log("📍 移动超过阈值，立即上报", log: playerLocationLog, type: .info)
                        Task {
                            await self.reportLocation(newLocation)
                        }
                    }
                }
            }
    }
}
