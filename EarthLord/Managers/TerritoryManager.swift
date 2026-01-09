//
//  TerritoryManager.swift
//  EarthLord
//
//  Created by Claude on 2026/1/8.
//

import Foundation
import CoreLocation
import Supabase

/// 领地管理器
/// 负责领地的上传和拉取
@MainActor
class TerritoryManager {

    // MARK: - Singleton

    static let shared = TerritoryManager()

    private init() {}

    // MARK: - Properties

    /// 缓存的领地数据（用于碰撞检测）
    private(set) var territories: [Territory] = []

    // MARK: - Upload Data Structure

    /// 上传领地的数据结构
    private struct UploadData: Encodable {
        let userId: String
        let path: [[String: Double]]
        let polygon: String
        let bboxMinLat: Double
        let bboxMaxLat: Double
        let bboxMinLon: Double
        let bboxMaxLon: Double
        let area: Double
        let pointCount: Int
        let startedAt: String
        let isActive: Bool

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case path
            case polygon
            case bboxMinLat = "bbox_min_lat"
            case bboxMaxLat = "bbox_max_lat"
            case bboxMinLon = "bbox_min_lon"
            case bboxMaxLon = "bbox_max_lon"
            case area
            case pointCount = "point_count"
            case startedAt = "started_at"
            case isActive = "is_active"
        }
    }

    // MARK: - Public Methods

    /// 上传领地到 Supabase
    /// - Parameters:
    ///   - coordinates: GPS 路径坐标数组
    ///   - area: 领地面积（平方米）
    ///   - startTime: 开始圈地时间
    func uploadTerritory(
        coordinates: [CLLocationCoordinate2D],
        area: Double,
        startTime: Date
    ) async throws {
        // 获取当前用户 ID
        guard let userId = try? await SupabaseService.shared.auth.session.user.id else {
            throw TerritoryError.userNotAuthenticated
        }

        // 转换数据格式
        let pathJSON = coordinatesToPathJSON(coordinates)
        let wktPolygon = coordinatesToWKT(coordinates)
        let bbox = calculateBoundingBox(coordinates)

        // 准备上传数据
        let uploadData = UploadData(
            userId: userId.uuidString,
            path: pathJSON,
            polygon: wktPolygon,
            bboxMinLat: bbox.minLat,
            bboxMaxLat: bbox.maxLat,
            bboxMinLon: bbox.minLon,
            bboxMaxLon: bbox.maxLon,
            area: area,
            pointCount: coordinates.count,
            startedAt: startTime.ISO8601Format(),
            isActive: true
        )

        // 上传到 Supabase
        do {
            try await SupabaseService.shared
                .from("territories")
                .insert(uploadData)
                .execute()

            print("✅ 领地上传成功！面积：\(area) m²，点数：\(coordinates.count)")
            TerritoryLogger.shared.log("领地上传成功！面积: \(Int(area))m²", type: .success)
        } catch {
            print("❌ 领地上传失败: \(error.localizedDescription)")
            TerritoryLogger.shared.log("领地上传失败: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    /// 拉取所有激活的领地
    func loadAllTerritories() async throws -> [Territory] {
        let territories: [Territory] = try await SupabaseService.shared
            .from("territories")
            .select()
            .eq("is_active", value: true)
            .execute()
            .value

        print("✅ 拉取到 \(territories.count) 个领地")
        return territories
    }

    /// 加载我的领地
    func loadMyTerritories() async throws -> [Territory] {
        guard let userId = try? await SupabaseService.shared.auth.session.user.id else {
            throw NSError(domain: "TerritoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录"])
        }

        let territories: [Territory] = try await SupabaseService.shared
            .from("territories")
            .select()
            .eq("user_id", value: userId.uuidString.lowercased())
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value

        print("✅ 加载到我的 \(territories.count) 个领地")
        TerritoryLogger.shared.log("加载到我的 \(territories.count) 个领地", type: .info)
        return territories
    }

    /// 删除领地
    func deleteTerritory(territoryId: String) async throws {
        try await SupabaseService.shared
            .from("territories")
            .delete()
            .eq("id", value: territoryId)
            .execute()

        print("✅ 删除领地成功: \(territoryId)")
        TerritoryLogger.shared.log("删除领地成功", type: .success)
    }

    /// 加载并缓存所有领地（用于碰撞检测）
    func loadAndCacheTerritories() async throws {
        territories = try await loadAllTerritories()
        print("✅ 缓存了 \(territories.count) 个领地用于碰撞检测")
    }

    // MARK: - Collision Detection Methods

    /// 射线法：判断点是否在多边形内
    /// - Parameters:
    ///   - point: 待检测的点
    ///   - polygon: 多边形顶点数组
    /// - Returns: true 表示点在多边形内
    func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var isInside = false
        var j = polygon.count - 1

        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            // 射线法：从点向右发射水平射线，计算与多边形边的交点数
            let intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
                (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)

            if intersect {
                isInside = !isInside
            }

            j = i
        }

        return isInside
    }

    /// 检测起始点是否在他人领地内
    /// - Parameters:
    ///   - point: 当前位置
    ///   - excludeUserId: 排除自己的用户 ID
    /// - Returns: 碰撞检测结果
    func checkPointCollision(point: CLLocationCoordinate2D, excludeUserId: String?) -> CollisionResult {
        print("🔍 checkPointCollision - territories.count: \(territories.count), excludeUserId: \(excludeUserId ?? "nil")")
        print("🔍 检测点坐标: (\(point.latitude), \(point.longitude))")

        for territory in territories {
            // 排除自己的领地（UUID 比较需要统一小写）
            if let excludeId = excludeUserId, territory.userId.lowercased() == excludeId.lowercased() {
                print("  ⏭️ 跳过自己的领地: \(territory.displayName)")
                continue
            }

            let polygon = territory.toCoordinates()
            print("  🔎 检查领地: \(territory.displayName), 点数: \(polygon.count)")

            if isPointInPolygon(point: point, polygon: polygon) {
                print("  ❌ 碰撞！点在领地 \(territory.displayName) 内")
                return CollisionResult(
                    hasCollision: true,
                    collisionType: .pointInTerritory,
                    message: "您当前位于他人领地内，无法开始圈地",
                    closestDistance: 0,
                    warningLevel: .violation,
                    territoryName: territory.displayName
                )
            }
        }

        print("  ✅ 点不在任何领地内")
        return CollisionResult.safe
    }

    /// CCW 算法：判断三点的方向
    /// - Returns: 正数表示逆时针，负数表示顺时针，0 表示共线
    private func ccw(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, _ c: CLLocationCoordinate2D) -> Double {
        return (b.longitude - a.longitude) * (c.latitude - a.latitude) -
               (b.latitude - a.latitude) * (c.longitude - a.longitude)
    }

    /// 判断两条线段是否相交
    /// - Parameters:
    ///   - p1, p2: 第一条线段的端点
    ///   - p3, p4: 第二条线段的端点
    /// - Returns: true 表示线段相交
    func segmentsIntersect(
        _ p1: CLLocationCoordinate2D,
        _ p2: CLLocationCoordinate2D,
        _ p3: CLLocationCoordinate2D,
        _ p4: CLLocationCoordinate2D
    ) -> Bool {
        let d1 = ccw(p3, p4, p1)
        let d2 = ccw(p3, p4, p2)
        let d3 = ccw(p1, p2, p3)
        let d4 = ccw(p1, p2, p4)

        if ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
           ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0)) {
            return true
        }

        // 检查共线情况
        let epsilon = 1e-10
        if abs(d1) < epsilon && onSegment(p3, p1, p4) { return true }
        if abs(d2) < epsilon && onSegment(p3, p2, p4) { return true }
        if abs(d3) < epsilon && onSegment(p1, p3, p2) { return true }
        if abs(d4) < epsilon && onSegment(p1, p4, p2) { return true }

        return false
    }

    /// 判断点 q 是否在线段 pr 上（假设三点共线）
    private func onSegment(
        _ p: CLLocationCoordinate2D,
        _ q: CLLocationCoordinate2D,
        _ r: CLLocationCoordinate2D
    ) -> Bool {
        return q.longitude <= max(p.longitude, r.longitude) &&
               q.longitude >= min(p.longitude, r.longitude) &&
               q.latitude <= max(p.latitude, r.latitude) &&
               q.latitude >= min(p.latitude, r.latitude)
    }

    /// 检测路径是否穿越他人领地边界
    /// - Parameters:
    ///   - path: 用户的路径坐标
    ///   - excludeUserId: 排除自己的用户 ID
    /// - Returns: 碰撞检测结果
    func checkPathCrossTerritory(path: [CLLocationCoordinate2D], excludeUserId: String?) -> CollisionResult {
        guard path.count >= 2 else { return CollisionResult.safe }

        // 检查路径的最后一段（新增的部分）
        let lastIndex = path.count - 1
        let newSegmentStart = path[lastIndex - 1]
        let newSegmentEnd = path[lastIndex]

        for territory in territories {
            // 排除自己的领地（UUID 比较需要统一小写）
            if let excludeId = excludeUserId, territory.userId.lowercased() == excludeId.lowercased() {
                continue
            }

            let polygon = territory.toCoordinates()
            guard polygon.count >= 3 else { continue }

            // 检查新线段是否与领地边界相交
            for i in 0..<polygon.count {
                let j = (i + 1) % polygon.count
                if segmentsIntersect(newSegmentStart, newSegmentEnd, polygon[i], polygon[j]) {
                    return CollisionResult(
                        hasCollision: true,
                        collisionType: .pathCrossTerritory,
                        message: "您的路径穿越了他人领地边界",
                        closestDistance: 0,
                        warningLevel: .violation,
                        territoryName: territory.displayName
                    )
                }
            }

            // 检查新路径点是否在领地内
            if isPointInPolygon(point: newSegmentEnd, polygon: polygon) {
                return CollisionResult(
                    hasCollision: true,
                    collisionType: .pointInTerritory,
                    message: "您进入了他人领地",
                    closestDistance: 0,
                    warningLevel: .violation,
                    territoryName: territory.displayName
                )
            }
        }

        return CollisionResult.safe
    }

    /// 计算点到线段的最短距离（米）
    private func pointToSegmentDistance(
        point: CLLocationCoordinate2D,
        segmentStart: CLLocationCoordinate2D,
        segmentEnd: CLLocationCoordinate2D
    ) -> Double {
        let pointLoc = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let startLoc = CLLocation(latitude: segmentStart.latitude, longitude: segmentStart.longitude)
        let endLoc = CLLocation(latitude: segmentEnd.latitude, longitude: segmentEnd.longitude)

        // 计算线段长度
        let segmentLength = startLoc.distance(from: endLoc)
        if segmentLength < 0.001 {
            return pointLoc.distance(from: startLoc)
        }

        // 计算投影比例
        let t = max(0, min(1, (
            (point.latitude - segmentStart.latitude) * (segmentEnd.latitude - segmentStart.latitude) +
            (point.longitude - segmentStart.longitude) * (segmentEnd.longitude - segmentStart.longitude)
        ) / (
            pow(segmentEnd.latitude - segmentStart.latitude, 2) +
            pow(segmentEnd.longitude - segmentStart.longitude, 2)
        )))

        // 计算最近点
        let nearestLat = segmentStart.latitude + t * (segmentEnd.latitude - segmentStart.latitude)
        let nearestLon = segmentStart.longitude + t * (segmentEnd.longitude - segmentStart.longitude)
        let nearestLoc = CLLocation(latitude: nearestLat, longitude: nearestLon)

        return pointLoc.distance(from: nearestLoc)
    }

    /// 计算点到最近领地的距离
    /// - Parameters:
    ///   - point: 当前位置
    ///   - excludeUserId: 排除自己的用户 ID
    /// - Returns: (最短距离, 最近的领地名称)
    func calculateMinDistanceToTerritories(point: CLLocationCoordinate2D, excludeUserId: String?) -> (distance: Double, territoryName: String?) {
        var minDistance = Double.infinity
        var closestTerritoryName: String?

        for territory in territories {
            // 排除自己的领地（UUID 比较需要统一小写）
            if let excludeId = excludeUserId, territory.userId.lowercased() == excludeId.lowercased() {
                continue
            }

            let polygon = territory.toCoordinates()
            guard polygon.count >= 3 else { continue }

            // 计算点到多边形每条边的最短距离
            for i in 0..<polygon.count {
                let j = (i + 1) % polygon.count
                let distance = pointToSegmentDistance(point: point, segmentStart: polygon[i], segmentEnd: polygon[j])

                if distance < minDistance {
                    minDistance = distance
                    closestTerritoryName = territory.displayName
                }
            }
        }

        return (minDistance, closestTerritoryName)
    }

    /// 根据距离确定预警级别
    private func warningLevelForDistance(_ distance: Double) -> WarningLevel {
        switch distance {
        case ..<0:
            return .violation
        case 0..<25:
            return .danger
        case 25..<50:
            return .warning
        case 50..<100:
            return .caution
        default:
            return .safe
        }
    }

    /// 综合碰撞检测（主要调用方法）
    /// - Parameters:
    ///   - currentPoint: 当前位置
    ///   - path: 当前路径（可选，用于路径穿越检测）
    ///   - excludeUserId: 排除自己的用户 ID
    /// - Returns: 碰撞检测结果
    func checkPathCollisionComprehensive(
        currentPoint: CLLocationCoordinate2D,
        path: [CLLocationCoordinate2D]?,
        excludeUserId: String?
    ) -> CollisionResult {
        // 1. 首先检查当前点是否在他人领地内
        let pointResult = checkPointCollision(point: currentPoint, excludeUserId: excludeUserId)
        if pointResult.hasCollision {
            return pointResult
        }

        // 2. 如果有路径，检查路径是否穿越他人领地
        if let path = path, path.count >= 2 {
            let pathResult = checkPathCrossTerritory(path: path, excludeUserId: excludeUserId)
            if pathResult.hasCollision {
                return pathResult
            }
        }

        // 3. 计算到最近领地的距离，生成预警
        let (distance, territoryName) = calculateMinDistanceToTerritories(point: currentPoint, excludeUserId: excludeUserId)
        let warningLevel = warningLevelForDistance(distance)

        // 生成预警消息
        var message: String?
        switch warningLevel {
        case .danger:
            message = "距离他人领地仅 \(Int(distance)) 米，请注意！"
        case .warning:
            message = "距离他人领地 \(Int(distance)) 米"
        case .caution:
            message = "附近有他人领地（\(Int(distance)) 米）"
        default:
            break
        }

        return CollisionResult(
            hasCollision: false,
            collisionType: nil,
            message: message,
            closestDistance: distance.isFinite ? distance : nil,
            warningLevel: warningLevel,
            territoryName: territoryName
        )
    }

    // MARK: - Private Helper Methods

    /// 将坐标转为 path JSON 格式：[{"lat": x, "lon": y}, ...]
    /// ⚠️ 只包含 lat 和 lon，不包含其他字段
    private func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coord in
            ["lat": coord.latitude, "lon": coord.longitude]
        }
    }

    /// 将坐标转为 WKT 格式
    /// ⚠️ WKT 格式：经度在前，纬度在后
    /// ⚠️ 多边形必须闭合（首尾相同）
    /// 示例：SRID=4326;POLYGON((121.4 31.2, 121.5 31.2, 121.5 31.3, 121.4 31.2))
    private func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        guard !coordinates.isEmpty else { return "" }

        var coords = coordinates

        // 确保多边形闭合（首尾相同）
        if let first = coords.first, let last = coords.last,
           first.latitude != last.latitude || first.longitude != last.longitude {
            coords.append(first)
        }

        // 生成 WKT 格式（经度在前，纬度在后）
        let wktPoints = coords.map { coord in
            "\(coord.longitude) \(coord.latitude)"
        }.joined(separator: ", ")

        return "SRID=4326;POLYGON((\(wktPoints)))"
    }

    /// 计算边界框
    private func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !coordinates.isEmpty else {
            return (0, 0, 0, 0)
        }

        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }

        return (
            minLat: lats.min() ?? 0,
            maxLat: lats.max() ?? 0,
            minLon: lons.min() ?? 0,
            maxLon: lons.max() ?? 0
        )
    }
}

// MARK: - Error Types

enum TerritoryError: LocalizedError {
    case userNotAuthenticated
    case invalidCoordinates

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "用户未登录"
        case .invalidCoordinates:
            return "无效的坐标数据"
        }
    }
}
