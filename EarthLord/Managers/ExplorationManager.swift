//
//  ExplorationManager.swift
//  EarthLord
//
//  Created by Claude on 2026/1/13.
//  探索管理器 - 管理探索状态、GPS追踪、距离/时长计算、速度检测
//

import Foundation
import CoreLocation
import Combine
import os.log

/// 探索日志器
private let explorationLog = OSLog(subsystem: "com.yanshuangren.EarthLord", category: "Exploration")

/// 探索状态枚举
enum ExplorationState: String {
    case idle = "空闲"
    case exploring = "探索中"
    case settling = "结算中"
    case failed = "探索失败"
}

/// 探索失败原因
enum ExplorationFailureReason {
    case speedViolation   // 速度超标
    case cancelled        // 用户取消
    case gpsError         // GPS错误
}

/// 探索管理器
/// 负责管理探索状态、GPS追踪、距离累加、时长计时、速度检测
@MainActor
class ExplorationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ExplorationManager()

    // MARK: - Published Properties

    /// 当前探索状态
    @Published var state: ExplorationState = .idle

    /// 累计行走距离（米）
    @Published var totalDistance: Double = 0

    /// 探索时长（秒）
    @Published var duration: TimeInterval = 0

    /// 当前速度（km/h）
    @Published var currentSpeed: Double = 0

    /// 是否正在超速
    @Published var isOverSpeed: Bool = false

    /// 超速倒计时（秒）
    @Published var speedViolationCountdown: Int = 0

    /// 速度警告消息
    @Published var speedWarningMessage: String?

    /// 探索开始时间
    @Published var startTime: Date?

    /// 探索开始坐标
    @Published var startCoordinate: CLLocationCoordinate2D?

    /// 探索结束坐标
    @Published var endCoordinate: CLLocationCoordinate2D?

    /// 当前会话ID
    @Published var currentSessionId: UUID?

    /// 错误信息
    @Published var errorMessage: String?

    /// 失败原因
    @Published var failureReason: ExplorationFailureReason?

    // MARK: - POI相关属性

    /// 附近的可探索POI
    @Published var nearbyPOIs: [ExplorablePOI] = []

    /// POI更新版本号（用于触发MapView刷新）
    @Published var poiUpdateVersion: Int = 0

    /// 当前接近的POI（用于弹窗）
    @Published var currentApproachingPOI: ExplorablePOI?

    /// 是否显示POI接近弹窗
    @Published var showPOIPopup: Bool = false

    /// 是否显示搜刮结果
    @Published var showScavengeResult: Bool = false

    /// 最后一次搜刮的奖励
    @Published var lastScavengeRewards: [GeneratedRewardItem] = []

    /// 是否正在探索
    var isExploring: Bool {
        state == .exploring
    }

    // MARK: - Private Properties

    /// 位置管理器
    private let locationManager = LocationManager.shared

    /// 上一个记录的位置
    private var lastLocation: CLLocation?

    /// 计时器（每秒更新）
    private var timer: Timer?

    /// 超速检测计时器
    private var speedViolationTimer: Timer?

    /// 位置订阅
    private var locationCancellable: AnyCancellable?

    /// 超速开始时间
    private var speedViolationStartTime: Date?

    /// 已搜刮的POI ID集合（持久化）
    private var scavengedPOIIds: Set<String> = []

    /// UserDefaults键名
    private let scavengedPOIsKey = "EarthLord_ScavengedPOIs"

    // MARK: - Constants

    /// GPS精度阈值（米）- 超过此值的点将被丢弃
    /// 真机GPS精度通常在5-65米，放宽到100米以便调试
    private let maximumAccuracyThreshold: Double = 100.0

    /// 距离跳变阈值（米）- 超过此值视为GPS跳点
    private let maximumDistanceJump: Double = 100.0

    /// 最小时间间隔（秒）- 两次记录之间的最小间隔
    private let minimumTimeInterval: TimeInterval = 1.0

    /// 最小移动距离（米）- 小于此距离不计入
    private let minimumMovementDistance: Double = 3.0

    /// 最大允许速度（km/h）
    private let maxAllowedSpeedKmh: Double = 20.0

    /// 最大允许速度（m/s）
    private var maxAllowedSpeedMs: Double {
        maxAllowedSpeedKmh / 3.6  // 20 km/h = 5.56 m/s
    }

    /// 超速容忍时间（秒）
    private let speedViolationToleranceSeconds: Int = 10

    /// POI触发半径（米）- 进入此范围弹出搜刮提示
    private let poiTriggerRadius: Double = 50.0

    /// POI搜索半径（米）- 改为3公里
    private let poiSearchRadius: Double = 3000.0

    // MARK: - Initialization

    private init() {
        // 加载已搜刮的POI IDs
        loadScavengedPOIs()

        print("🔭 [ExplorationManager] 初始化完成")
        print("   - 最大允许速度: \(maxAllowedSpeedKmh) km/h (\(String(format: "%.2f", maxAllowedSpeedMs)) m/s)")
        print("   - 超速容忍时间: \(speedViolationToleranceSeconds) 秒")
        print("   - GPS精度阈值: \(maximumAccuracyThreshold) 米")
        print("   - 已搜刮POI数量: \(scavengedPOIIds.count)")
    }

    // MARK: - Public Methods

    /// 开始探索
    func startExploration() {
        guard state == .idle else {
            print("⚠️ [ExplorationManager] 无法开始探索：当前状态为 \(state.rawValue)")
            return
        }

        print("═══════════════════════════════════════════════════")
        print("🚀 [ExplorationManager] 开始探索")
        print("═══════════════════════════════════════════════════")
        os_log("🚀 开始探索", log: explorationLog, type: .info)

        // 重置状态
        totalDistance = 0
        duration = 0
        currentSpeed = 0
        isOverSpeed = false
        speedViolationCountdown = 0
        speedWarningMessage = nil
        startTime = Date()
        lastLocation = nil
        currentSessionId = UUID()
        errorMessage = nil
        failureReason = nil
        speedViolationStartTime = nil

        // 重置POI相关状态
        nearbyPOIs = []
        poiUpdateVersion = 0
        currentApproachingPOI = nil
        showPOIPopup = false
        showScavengeResult = false
        lastScavengeRewards = []

        // 记录起始坐标
        if let location = locationManager.userLocation {
            startCoordinate = location.coordinate
            lastLocation = location
            print("📍 [ExplorationManager] 起始位置:")
            print("   - 纬度: \(location.coordinate.latitude)")
            print("   - 经度: \(location.coordinate.longitude)")
            print("   - 精度: \(String(format: "%.1f", location.horizontalAccuracy)) 米")
        } else {
            print("⚠️ [ExplorationManager] 警告：无法获取起始位置")
        }

        // 更新状态
        state = .exploring

        // 启动定时器（每秒更新时长和检查超速）
        startTimer()

        // ⚠️ 确保LocationManager正在更新位置！
        locationManager.startUpdatingLocation()
        print("📡 [ExplorationManager] 已启动位置更新")

        // 订阅位置更新
        subscribeToLocationUpdates()

        print("✅ [ExplorationManager] 探索已开始")
        print("   - 会话ID: \(currentSessionId?.uuidString ?? "nil")")
        print("   - 开始时间: \(startTime?.description ?? "nil")")
        print("═══════════════════════════════════════════════════")

        // 异步：上报位置 + 查询密度 + 加载POI
        Task {
            await loadNearbyPOIsWithDensity()
        }

        // 启动定时位置上报
        PlayerLocationManager.shared.startPeriodicReporting()
    }

    /// 结束探索（正常结束）
    /// - Returns: (距离, 时长, 奖励等级)
    func stopExploration() -> (distance: Double, duration: TimeInterval, tier: RewardTier) {
        guard state == .exploring else {
            print("⚠️ [ExplorationManager] 无法结束探索：当前状态为 \(state.rawValue)")
            return (0, 0, .none)
        }

        print("═══════════════════════════════════════════════════")
        print("🛑 [ExplorationManager] 正常结束探索")
        print("═══════════════════════════════════════════════════")

        // 更新状态为结算中
        state = .settling

        // 停止所有计时器
        stopAllTimers()

        // 停止定时位置上报
        PlayerLocationManager.shared.stopPeriodicReporting()

        // 取消位置订阅
        locationCancellable?.cancel()
        locationCancellable = nil

        // 记录结束坐标
        if let location = locationManager.userLocation {
            endCoordinate = location.coordinate
            print("📍 [ExplorationManager] 结束位置:")
            print("   - 纬度: \(location.coordinate.latitude)")
            print("   - 经度: \(location.coordinate.longitude)")
        }

        // 计算奖励等级
        let tier = RewardGenerator.calculateTier(distance: totalDistance)

        print("📊 [ExplorationManager] 探索结果:")
        print("   - 总距离: \(String(format: "%.1f", totalDistance)) 米")
        print("   - 总时长: \(formatDuration(duration))")
        print("   - 奖励等级: \(tier.rawValue)")
        print("═══════════════════════════════════════════════════")

        // 返回结果（状态稍后重置）
        return (totalDistance, duration, tier)
    }

    /// 因超速强制停止探索
    func forceStopDueToSpeed() {
        guard state == .exploring else { return }

        print("═══════════════════════════════════════════════════")
        print("🚫 [ExplorationManager] 因超速强制停止探索！")
        print("═══════════════════════════════════════════════════")

        // 更新状态
        state = .failed
        failureReason = .speedViolation
        errorMessage = "探索失败：移动速度超过 \(Int(maxAllowedSpeedKmh)) km/h 限制"

        // 停止所有计时器
        stopAllTimers()

        // 停止定时位置上报
        PlayerLocationManager.shared.stopPeriodicReporting()

        // 取消位置订阅
        locationCancellable?.cancel()
        locationCancellable = nil

        print("❌ [ExplorationManager] 探索已强制终止")
        print("   - 失败原因: 速度超标")
        print("   - 最后速度: \(String(format: "%.1f", currentSpeed)) km/h")
        print("   - 已行走距离: \(String(format: "%.1f", totalDistance)) 米")
        print("═══════════════════════════════════════════════════")
    }

    /// 完成结算，重置状态
    func finishSettlement() {
        print("✅ [ExplorationManager] 结算完成，重置状态")

        // 重置所有状态
        state = .idle
        totalDistance = 0
        duration = 0
        currentSpeed = 0
        isOverSpeed = false
        speedViolationCountdown = 0
        speedWarningMessage = nil
        startTime = nil
        startCoordinate = nil
        endCoordinate = nil
        lastLocation = nil
        currentSessionId = nil
        errorMessage = nil
        failureReason = nil
        speedViolationStartTime = nil

        // 重置POI相关状态
        nearbyPOIs = []
        poiUpdateVersion = 0
        currentApproachingPOI = nil
        showPOIPopup = false
        showScavengeResult = false
        lastScavengeRewards = []
    }

    /// 失败后重置状态（用于关闭失败横幅）
    func resetAfterFailure() {
        guard state == .failed else { return }

        print("🔄 [ExplorationManager] 失败后重置状态")

        // 重置所有状态
        state = .idle
        totalDistance = 0
        duration = 0
        currentSpeed = 0
        isOverSpeed = false
        speedViolationCountdown = 0
        speedWarningMessage = nil
        startTime = nil
        startCoordinate = nil
        endCoordinate = nil
        lastLocation = nil
        currentSessionId = nil
        errorMessage = nil
        failureReason = nil
        speedViolationStartTime = nil

        // 重置POI相关状态
        nearbyPOIs = []
        poiUpdateVersion = 0
        currentApproachingPOI = nil
        showPOIPopup = false
        showScavengeResult = false
        lastScavengeRewards = []
    }

    /// 取消探索（用户主动取消）
    func cancelExploration() {
        print("❌ [ExplorationManager] 用户取消探索")

        // 停止所有计时器
        stopAllTimers()

        // 停止定时位置上报
        PlayerLocationManager.shared.stopPeriodicReporting()

        // 取消位置订阅
        locationCancellable?.cancel()
        locationCancellable = nil

        // 重置状态
        state = .idle
        totalDistance = 0
        duration = 0
        currentSpeed = 0
        isOverSpeed = false
        speedViolationCountdown = 0
        speedWarningMessage = nil
        startTime = nil
        startCoordinate = nil
        endCoordinate = nil
        lastLocation = nil
        currentSessionId = nil
        errorMessage = nil
        failureReason = nil
        speedViolationStartTime = nil

        // 重置POI相关状态
        nearbyPOIs = []
        poiUpdateVersion = 0
        currentApproachingPOI = nil
        showPOIPopup = false
        showScavengeResult = false
        lastScavengeRewards = []
    }

    // MARK: - Private Methods

    /// 启动计时器
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.onTimerTick()
            }
        }
        print("⏱️ [ExplorationManager] 主计时器已启动（每秒）")
    }

    /// 停止所有计时器
    private func stopAllTimers() {
        timer?.invalidate()
        timer = nil
        speedViolationTimer?.invalidate()
        speedViolationTimer = nil
        print("⏱️ [ExplorationManager] 所有计时器已停止")
    }

    /// 计时器每秒回调
    private func onTimerTick() {
        guard state == .exploring else { return }

        // 更新时长
        if let start = startTime {
            duration = Date().timeIntervalSince(start)
        }

        // 检查超速状态
        checkSpeedViolation()
    }

    /// 检查超速状态
    private func checkSpeedViolation() {
        if isOverSpeed {
            // 正在超速
            if let violationStart = speedViolationStartTime {
                let elapsed = Int(Date().timeIntervalSince(violationStart))
                let remaining = speedViolationToleranceSeconds - elapsed

                if remaining > 0 {
                    speedViolationCountdown = remaining
                    speedWarningMessage = "速度过快！请在 \(remaining) 秒内减速，否则探索将失败"
                    print("⚠️ [ExplorationManager] 超速警告：剩余 \(remaining) 秒")
                } else {
                    // 超时，强制停止
                    print("🚫 [ExplorationManager] 超速时间已到，强制停止探索")
                    forceStopDueToSpeed()
                }
            }
        } else {
            // 速度正常，重置警告
            if speedViolationCountdown > 0 {
                print("✅ [ExplorationManager] 速度已恢复正常")
            }
            speedViolationCountdown = 0
            speedWarningMessage = nil
            speedViolationStartTime = nil
        }
    }

    /// 订阅位置更新
    private func subscribeToLocationUpdates() {
        locationCancellable = locationManager.$userLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                os_log("📡 收到位置订阅数据", log: explorationLog, type: .debug)
                Task { @MainActor in
                    self?.processLocationUpdate(location)
                }
            }
        print("📡 [ExplorationManager] 已订阅位置更新")
        os_log("📡 已订阅位置更新", log: explorationLog, type: .info)
    }

    /// 处理位置更新
    private func processLocationUpdate(_ newLocation: CLLocation) {
        guard state == .exploring else { return }

        let timestamp = DateFormatter.localizedString(from: newLocation.timestamp, dateStyle: .none, timeStyle: .medium)

        // ⚠️ 关键日志：确认位置更新被接收
        os_log("📍 位置更新: lat=%{public}.6f, lon=%{public}.6f, acc=%{public}.1fm",
               log: explorationLog, type: .info,
               newLocation.coordinate.latitude,
               newLocation.coordinate.longitude,
               newLocation.horizontalAccuracy)
        print("📍 [位置更新] \(timestamp) - (\(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude)) 精度:\(Int(newLocation.horizontalAccuracy))m")

        // ⚠️ 先检查POI接近（即使GPS精度不够也要检查）
        checkPOIProximity(newLocation)

        // 1. 检查GPS精度（影响距离累加，但不影响POI检测）
        let accuracy = newLocation.horizontalAccuracy
        if accuracy > maximumAccuracyThreshold || accuracy < 0 {
            print("📡 [ExplorationManager] [\(timestamp)] GPS精度不足: \(String(format: "%.1f", accuracy))m > \(maximumAccuracyThreshold)m，不累加距离")
            return
        }

        // 2. 如果是第一个点，直接记录
        guard let last = lastLocation else {
            lastLocation = newLocation
            print("📍 [ExplorationManager] [\(timestamp)] 记录第一个位置点")
            return
        }

        // 3. 检查时间间隔
        let timeInterval = newLocation.timestamp.timeIntervalSince(last.timestamp)
        if timeInterval < minimumTimeInterval {
            return // 时间间隔太短，静默忽略
        }

        // 4. 计算距离
        let distance = newLocation.distance(from: last)

        // 5. 计算速度（m/s 转 km/h）
        let speedMs = timeInterval > 0 ? distance / timeInterval : 0
        let speedKmh = speedMs * 3.6
        currentSpeed = speedKmh

        print("📊 [ExplorationManager] [\(timestamp)] 位置更新:")
        print("   - 移动距离: \(String(format: "%.1f", distance)) 米")
        print("   - 时间间隔: \(String(format: "%.1f", timeInterval)) 秒")
        print("   - 当前速度: \(String(format: "%.1f", speedKmh)) km/h")

        // 6. 检查速度是否超标
        if speedKmh > maxAllowedSpeedKmh {
            print("🚨 [ExplorationManager] 速度超标！\(String(format: "%.1f", speedKmh)) km/h > \(maxAllowedSpeedKmh) km/h")

            if !isOverSpeed {
                // 刚开始超速
                isOverSpeed = true
                speedViolationStartTime = Date()
                speedViolationCountdown = speedViolationToleranceSeconds
                speedWarningMessage = "速度过快！请在 \(speedViolationToleranceSeconds) 秒内减速"
                print("⚠️ [ExplorationManager] 开始超速计时，\(speedViolationToleranceSeconds) 秒后将强制停止")
            }

            // 超速时不计入距离
            print("   - 超速中，距离不计入")
            return
        } else {
            // 速度正常
            if isOverSpeed {
                print("✅ [ExplorationManager] 速度恢复正常: \(String(format: "%.1f", speedKmh)) km/h")
            }
            isOverSpeed = false
            speedViolationStartTime = nil
        }

        // 7. 检查距离跳变（GPS跳点）
        if distance > maximumDistanceJump {
            print("⚠️ [ExplorationManager] GPS跳点检测: \(String(format: "%.1f", distance))m > \(maximumDistanceJump)m，忽略")
            return
        }

        // 8. 检查最小移动距离
        if distance < minimumMovementDistance {
            print("   - 移动距离太小 (\(String(format: "%.1f", distance))m < \(minimumMovementDistance)m)，不计入")
            return
        }

        // 9. 累加距离
        let oldDistance = totalDistance
        totalDistance += distance
        lastLocation = newLocation

        print("✅ [ExplorationManager] 距离已累加: \(String(format: "%.1f", oldDistance)) + \(String(format: "%.1f", distance)) = \(String(format: "%.1f", totalDistance)) 米")
        os_log("✅ 距离累加: %{public}.1f + %{public}.1f = %{public}.1f 米",
               log: explorationLog, type: .info,
               oldDistance, distance, totalDistance)
    }

    // MARK: - 格式化方法

    /// 格式化距离显示
    func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    /// 格式化时长显示
    func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    /// 格式化速度显示
    func formatSpeed(_ kmh: Double) -> String {
        return String(format: "%.1f km/h", kmh)
    }

    // MARK: - POI Methods

    /// 基于玩家密度加载附近POI（完整流程）
    func loadNearbyPOIsWithDensity() async {
        print("═══════════════════════════════════════════════════")
        print("🔍 [ExplorationManager] loadNearbyPOIsWithDensity() 开始")
        os_log("🔍 开始基于密度的POI加载", log: explorationLog, type: .info)

        guard let location = locationManager.userLocation else {
            print("❌ [POI加载] 失败：没有用户位置")
            os_log("❌ POI加载失败: 没有用户位置", log: explorationLog, type: .error)
            print("═══════════════════════════════════════════════════")
            return
        }

        // Step 1: 上报当前位置
        print("📤 Step 1: 上报当前位置...")
        await PlayerLocationManager.shared.reportLocation(location)

        // Step 2: 查询附近玩家数量
        print("🔍 Step 2: 查询附近玩家数量...")
        let nearbyCount = await PlayerLocationManager.shared.queryNearbyPlayers(at: location)
        let density = PlayerLocationManager.shared.densityLevel
        let maxPOIs = density.maxPOICount

        print("📊 密度检测结果:")
        print("   - 附近玩家: \(nearbyCount) 人")
        print("   - 密度等级: \(density.rawValue)")
        print("   - POI上限: \(maxPOIs) 个")
        os_log("📊 密度: %{public}d人, %{public}@, POI上限%{public}d",
               log: explorationLog, type: .info, nearbyCount, density.rawValue, maxPOIs)

        // Step 3: 根据密度加载POI
        print("🗺️ Step 3: 搜索附近POI (上限\(maxPOIs)个)...")
        await loadNearbyPOIs(maxCount: maxPOIs)

        print("✅ [ExplorationManager] 基于密度的POI加载完成")
        print("═══════════════════════════════════════════════════")
    }

    /// 加载附近的POI
    /// - Parameter maxCount: 最大返回数量（根据密度动态调整）
    func loadNearbyPOIs(maxCount: Int = 20) async {
        print("═══════════════════════════════════════════════════")
        print("🔍 [ExplorationManager] loadNearbyPOIs(maxCount: \(maxCount)) 被调用")
        os_log("🔍 loadNearbyPOIs() 开始执行, maxCount=%{public}d", log: explorationLog, type: .info, maxCount)

        guard let location = locationManager.userLocation else {
            print("❌ [POI加载] 失败：没有用户位置")
            os_log("❌ POI加载失败: 没有用户位置", log: explorationLog, type: .error)
            print("═══════════════════════════════════════════════════")
            return
        }

        print("📍 [POI加载] 当前位置: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        print("📏 [POI加载] 搜索半径: \(poiSearchRadius)米")
        os_log("📍 POI加载位置: (%{public}.6f, %{public}.6f) 半径: %{public}.0fm",
               log: explorationLog, type: .info,
               location.coordinate.latitude, location.coordinate.longitude, poiSearchRadius)

        do {
            print("🔄 [POI加载] 正在调用POISearchManager...")
            os_log("🔄 正在调用POISearchManager...", log: explorationLog, type: .info)

            let pois = try await POISearchManager.shared.searchNearbyPOIs(
                center: location.coordinate,
                radiusMeters: poiSearchRadius,
                maxCount: maxCount
            )

            print("🔄 [POI加载] POISearchManager返回: \(pois.count) 个POI")
            os_log("🔄 POISearchManager返回: %{public}d个POI", log: explorationLog, type: .info, pois.count)

            // 恢复已搜刮状态
            var poisWithState = pois
            var scavengedCount = 0
            for i in poisWithState.indices {
                if scavengedPOIIds.contains(poisWithState[i].id) {
                    poisWithState[i].isScavenged = true
                    scavengedCount += 1
                }
            }

            nearbyPOIs = poisWithState
            poiUpdateVersion += 1  // ⚠️ 关键：触发MapView刷新

            print("✅ [POI加载] 成功！更新了 \(pois.count) 个POI, 其中 \(scavengedCount) 个已搜刮, 版本号: \(poiUpdateVersion)")
            os_log("✅ POI加载成功: %{public}d个(已搜刮%{public}d个), 版本号: %{public}d",
                   log: explorationLog, type: .info, pois.count, scavengedCount, poiUpdateVersion)

            // 打印每个POI的信息
            for (index, poi) in poisWithState.enumerated() {
                let dist = poi.distance(from: location)
                let status = poi.isScavenged ? "✓已搜刮" : ""
                print("   \(index + 1). \(poi.name) [\(poi.type.rawValue)] - \(Int(dist))m \(status)")
            }
        } catch {
            print("❌ [POI加载] 失败: \(error.localizedDescription)")
            print("   错误详情: \(error)")
            os_log("❌ POI加载失败: %{public}@", log: explorationLog, type: .error, error.localizedDescription)
        }
        print("═══════════════════════════════════════════════════")
    }

    /// 检查是否接近任何POI
    /// - Parameter location: 当前用户位置
    func checkPOIProximity(_ location: CLLocation) {
        // 如果弹窗已显示或正在显示结果，不检查
        guard !showPOIPopup && !showScavengeResult else {
            return
        }

        // 如果没有POI，不检查
        guard !nearbyPOIs.isEmpty else {
            return
        }

        // 检查所有未搜刮的POI
        let unscavengedPOIs = nearbyPOIs.filter { !$0.isScavenged }

        for poi in unscavengedPOIs {
            let distance = poi.distance(from: location)

            if distance <= poiTriggerRadius {
                print("✨ [POI] 进入范围！\(poi.name) (距离: \(Int(distance))m)")
                os_log("✨ 进入POI范围: %{public}@ 距离%{public}.0fm",
                       log: explorationLog, type: .info, poi.name, distance)
                currentApproachingPOI = poi
                showPOIPopup = true
                return
            } else if distance <= 100 {
                // 打印100米内的POI距离
                os_log("📍 接近POI: %{public}@ %{public}.0fm",
                       log: explorationLog, type: .debug, poi.name, distance)
            }
        }
    }

    /// 搜刮POI
    /// - Parameter poi: 要搜刮的POI
    /// - Returns: 获得的物品列表
    func scavengePOI(_ poi: ExplorablePOI) async -> [GeneratedRewardItem] {
        print("═══════════════════════════════════════════════════")
        print("🎁 [ExplorationManager] 搜刮POI: \(poi.name)")
        print("   - 类型: \(poi.type.rawValue)")
        print("   - 危险等级: \(poi.type.dangerLevel)")
        print("═══════════════════════════════════════════════════")
        os_log("🎁 搜刮POI: %{public}@ [%{public}@] 危险等级:%{public}d",
               log: explorationLog, type: .info, poi.name, poi.type.rawValue, poi.type.dangerLevel)

        // 使用AI生成器生成物品（自动降级到本地生成）
        let rewards = await AIItemGenerator.shared.generateItems(for: poi)

        // 标记为已搜刮（内存和持久化）
        if let index = nearbyPOIs.firstIndex(where: { $0.id == poi.id }) {
            nearbyPOIs[index].isScavenged = true
            poiUpdateVersion += 1  // 触发地图标记刷新
        }
        markPOIAsScavenged(poi.id)  // 持久化保存

        // 保存奖励
        lastScavengeRewards = rewards

        // 添加到背包
        await saveRewardsToInventory(rewards)

        // 关闭搜刮弹窗，显示结果
        showPOIPopup = false
        showScavengeResult = true

        os_log("🎁 搜刮完成: 获得%{public}d件物品",
               log: explorationLog, type: .info, rewards.count)
        for reward in rewards {
            print("   - \(reward.name) x\(reward.quantity)")
            os_log("   物品: %{public}@ x%{public}d",
                   log: explorationLog, type: .info, reward.name, reward.quantity)
        }

        return rewards
    }

    /// 保存奖励到背包
    private func saveRewardsToInventory(_ rewards: [GeneratedRewardItem]) async {
        // 直接使用 InventoryManager 的 addItems 方法
        // 使用 "scavenge" 作为来源，避免数据库约束冲突
        await InventoryManager.shared.addItems(rewards, source: "scavenge")
        print("✅ [ExplorationManager] 物品已保存到背包")
    }

    /// 关闭POI弹窗
    func dismissPOIPopup() {
        showPOIPopup = false
        currentApproachingPOI = nil
        print("📍 [ExplorationManager] POI弹窗已关闭")
    }

    /// 关闭搜刮结果弹窗
    func dismissScavengeResult() {
        showScavengeResult = false
        currentApproachingPOI = nil
        lastScavengeRewards = []
        print("📍 [ExplorationManager] 搜刮结果弹窗已关闭")
    }

    // MARK: - POI搜刮状态持久化

    /// 加载已搜刮的POI IDs
    private func loadScavengedPOIs() {
        if let savedIds = UserDefaults.standard.array(forKey: scavengedPOIsKey) as? [String] {
            scavengedPOIIds = Set(savedIds)
            print("📦 [ExplorationManager] 加载已搜刮POI: \(scavengedPOIIds.count) 个")
        }
    }

    /// 保存已搜刮的POI IDs
    private func saveScavengedPOIs() {
        UserDefaults.standard.set(Array(scavengedPOIIds), forKey: scavengedPOIsKey)
        print("💾 [ExplorationManager] 保存已搜刮POI: \(scavengedPOIIds.count) 个")
    }

    /// 标记POI为已搜刮
    private func markPOIAsScavenged(_ poiId: String) {
        scavengedPOIIds.insert(poiId)
        saveScavengedPOIs()
        print("✅ [ExplorationManager] POI已标记为已搜刮: \(poiId)")
    }

    /// 检查POI是否已搜刮
    func isPOIScavenged(_ poiId: String) -> Bool {
        return scavengedPOIIds.contains(poiId)
    }

    /// 重置所有POI搜刮状态（用于调试）
    func resetAllScavengedPOIs() {
        scavengedPOIIds.removeAll()
        saveScavengedPOIs()
        print("🔄 [ExplorationManager] 已重置所有POI搜刮状态")
    }
}
