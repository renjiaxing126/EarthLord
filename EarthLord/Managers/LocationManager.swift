//
//  LocationManager.swift
//  EarthLord
//
//  Created by Claude Code on 2026/1/6.
//

import Foundation
import CoreLocation
import Combine

/// GPS 定位管理器
class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    // MARK: - Published Properties

    /// 用户当前位置
    @Published var userLocation: CLLocation?

    /// 定位权限状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 定位错误信息
    @Published var locationError: String?

    /// 是否正在追踪路径
    @Published var isTracking = false

    /// 路径坐标数组（存储原始 WGS-84 坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于触发 SwiftUI 更新）
    @Published var pathUpdateVersion = 0

    /// 路径是否闭合
    @Published var isPathClosed = false

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed = false

    // MARK: - 验证状态属性

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误信息
    @Published var territoryValidationError: String? = nil

    /// 计算得到的领地面积（平方米）
    @Published var calculatedArea: Double = 0

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()

    /// 当前位置（用于 Timer 采点）
    private var currentLocation: CLLocation?

    /// 路径更新定时器（每 2 秒检查一次）
    private var pathUpdateTimer: Timer?

    /// 上次位置时间戳（用于速度检测）
    private var lastLocationTimestamp: Date?

    // MARK: - Constants

    /// 闭环距离阈值（米）
    /// ✅ 修复：从30m增加到50m，考虑真机GPS误差（5-10米）
    private let closureDistanceThreshold: Double = 50.0

    /// 最少路径点数（闭环检测需要）
    private let minimumPathPoints: Int = 10

    /// 新点距离阈值（米）
    private let minimumDistanceForNewPoint: Double = 10.0

    /// GPS精度阈值（米）- 用于速度检测
    /// 如果 horizontalAccuracy > 25米，跳过速度检测
    private let maximumAcceptableAccuracy: Double = 25.0

    /// GPS精度阈值（米）- 用于丢弃点
    /// 如果 horizontalAccuracy > 50米，直接丢弃该点，不记录
    private let maximumAccuracyForRecording: Double = 50.0

    /// 连续低精度点计数（用于减少日志频率）
    private var lowAccuracyCount: Int = 0

    /// 速度警告阈值（km/h）
    /// ✅ 修复：从15提高到25，避免GPS漂移误判（正常快走6-8 km/h，慢跑10-12 km/h）
    private let speedWarningThreshold: Double = 25.0

    /// 速度限制阈值（km/h）
    private let speedLimitThreshold: Double = 30.0

    // MARK: - 验证常量

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 50.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 100.0

    // MARK: - Computed Properties

    /// 是否已授权定位
    var isAuthorized: Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// 是否拒绝定位
    var isDenied: Bool {
        return authorizationStatus == .denied || authorizationStatus == .restricted
    }

    // MARK: - Initialization

    private override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // 移动10米以上才更新位置

        print("📍 LocationManager 初始化完成，当前权限状态: \(authorizationStatus.description)")
    }

    // MARK: - Public Methods

    /// 请求定位权限
    func requestPermission() {
        print("🔐 请求定位权限")
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始更新位置
    func startUpdatingLocation() {
        guard isAuthorized else {
            print("⚠️ 未授权定位，无法开始更新位置")
            locationError = "请在设置中允许访问位置信息"
            return
        }

        print("▶️ 开始更新位置")
        locationManager.startUpdatingLocation()
    }

    /// 停止更新位置
    func stopUpdatingLocation() {
        print("⏸️ 停止更新位置")
        locationManager.stopUpdatingLocation()
    }

    // MARK: - 路径追踪方法

    /// 开始追踪路径
    func startPathTracking() {
        guard isAuthorized else {
            print("⚠️ 未授权定位，无法开始追踪")
            TerritoryLogger.shared.log("定位未授权，无法开始追踪", type: .error)
            return
        }

        print("🚩 开始追踪路径")
        isTracking = true
        pathCoordinates = []
        pathUpdateVersion = 0
        isPathClosed = false
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil

        // ✅ 重置验证状态（修复：防止上次验证结果残留）
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

        // 记录日志
        TerritoryLogger.shared.log("开始圈地追踪", type: .info)

        // 启动定时器，每 2 秒检查一次位置
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }
    }

    /// 停止追踪路径
    func stopPathTracking() {
        print("🛑 停止追踪路径")
        isTracking = false

        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        print("📊 路径追踪完成，共 \(pathCoordinates.count) 个点")

        // 记录日志
        TerritoryLogger.shared.log("停止追踪，共 \(pathCoordinates.count) 个点", type: .info)

        // ⚠️ 重置所有状态（防止重复上传）
        pathCoordinates = []
        pathUpdateVersion = 0
        isPathClosed = false
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil
    }

    /// 清除路径
    func clearPath() {
        print("🗑️ 清除路径")
        pathCoordinates = []
        pathUpdateVersion = 0
        isPathClosed = false
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil

        // ✅ 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
    }

    /// 记录路径点（定时器回调）
    /// ⚠️ 关键：先检查GPS精度，再检查距离，最后检查速度！
    private func recordPathPoint() {
        guard isTracking else { return }
        guard let location = currentLocation else {
            print("⚠️ 当前位置为空，跳过记录")
            return
        }

        // 步骤0：检查 GPS 精度（过滤严重漂移点）
        let accuracy = location.horizontalAccuracy
        if accuracy > maximumAccuracyForRecording {
            // GPS 精度太差（>50m），直接丢弃该点
            lowAccuracyCount += 1
            // 每 5 次才打印一次日志，减少日志刷屏
            if lowAccuracyCount % 5 == 1 {
                print("📡 GPS精度太差（\(String(format: "%.1f", accuracy))m），丢弃该点")
                TerritoryLogger.shared.log("GPS精度太差（\(String(format: "%.0f", accuracy))m），已丢弃", type: .warning)
            }
            return
        }
        lowAccuracyCount = 0  // 重置计数

        // 步骤1：先检查距离（过滤 GPS 漂移，距离不够就直接返回）
        var distanceFromLast: Double = 0
        if let lastCoordinate = pathCoordinates.last {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            distanceFromLast = location.distance(from: lastLocation)

            guard distanceFromLast >= minimumDistanceForNewPoint else {
                // 距离不够，不打印日志（避免刷屏）
                return
            }
        }

        // 步骤2：再检查速度（只对真实移动进行检测，传入已计算的距离）
        guard validateMovementSpeed(newLocation: location, distance: distanceFromLast) else {
            return  // 严重超速，不记录
        }

        // 步骤3：记录新点
        pathCoordinates.append(location.coordinate)
        pathUpdateVersion += 1
        let pointCount = pathCoordinates.count

        // 步骤4：更新时间戳（只有成功记录点后才更新）
        lastLocationTimestamp = Date()

        // 步骤5：记录日志（简化输出）
        if pointCount == 1 {
            TerritoryLogger.shared.log("记录第 1 个点（起点）", type: .info)
        } else {
            TerritoryLogger.shared.log("记录第 \(pointCount) 个点，距上点 \(String(format: "%.1f", distanceFromLast))m", type: .info)
        }

        // 步骤6：检测闭环
        checkPathClosure()
    }

    // MARK: - 闭环检测

    /// 检测路径是否闭合
    private func checkPathClosure() {
        // 已经闭合了，不需要再检测
        guard !isPathClosed else { return }

        // 检查点数是否足够
        guard pathCoordinates.count >= minimumPathPoints else {
            print("🔍 闭环检测：点数不足（\(pathCoordinates.count)/\(minimumPathPoints)）")
            return
        }

        // 获取起点和当前点
        guard let startPoint = pathCoordinates.first,
              let currentPoint = pathCoordinates.last else {
            return
        }

        // 计算起点到当前点的距离
        let startLocation = CLLocation(latitude: startPoint.latitude, longitude: startPoint.longitude)
        let currentLocation = CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude)
        let distance = startLocation.distance(from: currentLocation)

        print("🔍 闭环检测：距离起点 \(String(format: "%.1f", distance))米（阈值 \(closureDistanceThreshold)米）")

        // 记录闭环检测日志（点数≥10后才显示）
        TerritoryLogger.shared.log("距起点 \(String(format: "%.1f", distance))m (需≤\(Int(closureDistanceThreshold))m)", type: .info)

        // 检查是否在阈值内
        if distance <= closureDistanceThreshold {
            isPathClosed = true
            pathUpdateVersion += 1
            print("✅ 闭环检测成功！路径已闭合，共 \(pathCoordinates.count) 个点")

            // 记录闭环成功日志
            TerritoryLogger.shared.log("闭环成功！距起点 \(String(format: "%.1f", distance))m", type: .success)

            // ⚠️ 闭环成功后，自动触发领地验证
            let result = validateTerritory()
            territoryValidationPassed = result.isValid
            territoryValidationError = result.errorMessage

            if result.isValid {
                // 验证通过，记录计算的面积
                calculatedArea = calculatePolygonArea()
            } else {
                // 验证失败，面积设为 0
                calculatedArea = 0
            }
        }
    }

    // MARK: - 速度检测

    /// 验证移动速度
    /// - Parameters:
    ///   - newLocation: 新位置
    ///   - distance: 距离上个点的距离（米）
    /// - Returns: true 表示可以记录该点，false 表示不记录
    private func validateMovementSpeed(newLocation: CLLocation, distance: Double) -> Bool {
        // 第一个点，直接记录（不需要速度检测）
        guard let lastTimestamp = lastLocationTimestamp else {
            return true
        }

        // ✅ 修复：GPS精度检查（防止漂移导致的误判）
        let accuracy = newLocation.horizontalAccuracy
        if accuracy > maximumAcceptableAccuracy {
            // 精度差的位置依然记录，但不进行速度检测，避免误判
            // 不打印日志，减少刷屏
            return true
        }

        // 计算时间差（秒）
        let currentTime = Date()
        let timeDiff = currentTime.timeIntervalSince(lastTimestamp)

        // ✅ 修复：时间间隔太短（<5秒），不进行速度检测，避免误判
        // GPS 更新和距离累积需要时间，太短的间隔容易因为 GPS 漂移导致高速度
        guard timeDiff >= 5.0 else {
            // 时间间隔太短，不打印日志
            return true
        }

        // 计算速度（km/h）
        let speed = (distance / timeDiff) * 3.6

        // 只有超速才打印日志
        if speed > speedWarningThreshold {
            print("🚗 速度检测：\(String(format: "%.1f", speed)) km/h（距离 \(String(format: "%.1f", distance))m，时间 \(String(format: "%.1f", timeDiff))s）")
        }

        // 严重超速（>30 km/h），停止追踪
        if speed > speedLimitThreshold {
            speedWarning = String(format: "速度过快（%.1f km/h），已停止追踪", speed)
            isOverSpeed = true
            print("🚨 严重超速：\(String(format: "%.1f", speed)) km/h，停止追踪")

            // 记录超速日志
            TerritoryLogger.shared.log("超速 \(String(format: "%.1f", speed)) km/h，已停止追踪", type: .error)

            stopPathTracking()
            return false
        }

        // 超速警告（15-30 km/h），继续记录但警告
        if speed > speedWarningThreshold {
            speedWarning = String(format: "速度较快（%.1f km/h），请注意", speed)
            isOverSpeed = true
            print("⚠️ 速度警告：\(String(format: "%.1f", speed)) km/h")

            // 记录速度警告日志
            TerritoryLogger.shared.log("速度较快 \(String(format: "%.1f", speed)) km/h", type: .warning)

            return true
        }

        // 正常速度，清除警告
        speedWarning = nil
        isOverSpeed = false
        return true
    }

    // MARK: - 距离与面积计算

    /// 计算路径总距离
    /// - Returns: 总距离（米）
    private func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var totalDistance: Double = 0

        for i in 0..<(pathCoordinates.count - 1) {
            let current = CLLocation(
                latitude: pathCoordinates[i].latitude,
                longitude: pathCoordinates[i].longitude
            )
            let next = CLLocation(
                latitude: pathCoordinates[i + 1].latitude,
                longitude: pathCoordinates[i + 1].longitude
            )
            totalDistance += current.distance(from: next)
        }

        return totalDistance
    }

    /// 使用鞋带公式计算多边形面积（考虑地球曲率）
    /// - Returns: 面积（平方米）
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        let earthRadius: Double = 6371000 // 地球半径（米）
        var area: Double = 0

        for i in 0..<pathCoordinates.count {
            let current = pathCoordinates[i]
            let next = pathCoordinates[(i + 1) % pathCoordinates.count] // 循环取点

            // 经纬度转弧度
            let lat1 = current.latitude * .pi / 180
            let lon1 = current.longitude * .pi / 180
            let lat2 = next.latitude * .pi / 180
            let lon2 = next.longitude * .pi / 180

            // 鞋带公式（球面修正）
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        area = abs(area * earthRadius * earthRadius / 2.0)
        return area
    }

    // MARK: - 自相交检测

    /// 判断两条线段是否相交（使用 CCW 算法）
    /// - Parameters:
    ///   - p1: 第一条线段的起点
    ///   - p2: 第一条线段的终点
    ///   - p3: 第二条线段的起点
    ///   - p4: 第二条线段的终点
    /// - Returns: true 表示相交
    private func segmentsIntersect(
        p1: CLLocationCoordinate2D,
        p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D,
        p4: CLLocationCoordinate2D
    ) -> Bool {
        /// CCW 辅助函数：判断三点的方向（逆时针为 true）
        /// - Parameters:
        ///   - a: 点 A
        ///   - b: 点 B
        ///   - c: 点 C
        /// - Returns: 叉积 > 0 则为逆时针
        func ccw(a: CLLocationCoordinate2D, b: CLLocationCoordinate2D, c: CLLocationCoordinate2D) -> Bool {
            // ⚠️ 坐标映射：longitude = X轴，latitude = Y轴
            // 计算叉积 = (Cy - Ay) × (Bx - Ax) - (By - Ay) × (Cx - Ax)
            let crossProduct = (c.latitude - a.latitude) * (b.longitude - a.longitude) -
                               (b.latitude - a.latitude) * (c.longitude - a.longitude)
            return crossProduct > 0
        }

        // 判断逻辑：
        // ccw(p1, p3, p4) ≠ ccw(p2, p3, p4) 且
        // ccw(p1, p2, p3) ≠ ccw(p1, p2, p4)
        return ccw(a: p1, b: p3, c: p4) != ccw(a: p2, b: p3, c: p4) &&
               ccw(a: p1, b: p2, c: p3) != ccw(a: p1, b: p2, c: p4)
    }

    /// 检测路径是否自相交
    /// - Returns: true 表示有自交
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量
        let skipHeadCount = 2
        let skipTailCount = 2

        for i in 0..<segmentCount {
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 跳过首尾附近线段的比较
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount

                if isHeadSegment && isTailSegment {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交", type: .error)
                    return true
                }
            }
        }

        TerritoryLogger.shared.log("自交检测: 无交叉 ✓", type: .info)
        return false
    }

    // MARK: - 综合验证

    /// 验证领地是否符合规则
    /// - Returns: (isValid: 验证是否通过, errorMessage: 错误信息)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始领地验证", type: .info)

        // 1. 点数检查
        let pointCount = pathCoordinates.count
        if pointCount < minimumPathPoints {
            let errorMsg = "点数不足: \(pointCount)个点 (需≥\(minimumPathPoints)个点)"
            TerritoryLogger.shared.log(errorMsg, type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("点数检查: \(pointCount)个点 ✓", type: .info)

        // 2. 距离检查
        let totalDistance = calculateTotalPathDistance()
        if totalDistance < minimumTotalDistance {
            let errorMsg = String(format: "距离不足: %.0fm (需≥%.0fm)", totalDistance, minimumTotalDistance)
            TerritoryLogger.shared.log(errorMsg, type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log(String(format: "距离检查: %.0fm ✓", totalDistance), type: .info)

        // 3. 自交检测
        if hasPathSelfIntersection() {
            let errorMsg = "轨迹自相交，请勿画8字形"
            TerritoryLogger.shared.log(errorMsg, type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, errorMsg)
        }
        // 注意：hasPathSelfIntersection 内部已经记录了日志

        // 4. 面积检查
        let area = calculatePolygonArea()
        if area < minimumEnclosedArea {
            let errorMsg = String(format: "面积不足: %.0fm² (需≥%.0fm²)", area, minimumEnclosedArea)
            TerritoryLogger.shared.log(errorMsg, type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log(String(format: "面积检查: %.0fm² ✓", area), type: .info)

        // 所有检查通过
        TerritoryLogger.shared.log(String(format: "领地验证通过！面积: %.0fm²", area), type: .success)
        return (true, nil)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    /// 定位权限状态改变
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        print("🔄 定位权限状态改变: \(authorizationStatus.description) -> \(newStatus.description)")

        authorizationStatus = newStatus

        // 如果授权成功，自动开始更新位置
        if isAuthorized {
            print("✅ 定位权限已授权，开始更新位置")
            startUpdatingLocation()
        } else if isDenied {
            print("❌ 定位权限被拒绝")
            locationError = "定位权限被拒绝，请在设置中开启"
        }
    }

    /// 位置更新成功
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        print("📍 位置更新成功: 纬度 \(location.coordinate.latitude), 经度 \(location.coordinate.longitude)")
        userLocation = location
        currentLocation = location // Timer 需要用这个
        locationError = nil
    }

    /// 位置更新失败
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 位置更新失败: \(error.localizedDescription)")

        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = "定位权限被拒绝"
            case .locationUnknown:
                locationError = "无法获取位置信息"
            case .network:
                locationError = "网络错误，无法获取位置"
            default:
                locationError = "定位失败: \(error.localizedDescription)"
            }
        } else {
            locationError = "定位失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - CLAuthorizationStatus Extension

extension CLAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined:
            return "未确定"
        case .restricted:
            return "受限制"
        case .denied:
            return "已拒绝"
        case .authorizedAlways:
            return "始终允许"
        case .authorizedWhenInUse:
            return "使用时允许"
        @unknown default:
            return "未知"
        }
    }
}
