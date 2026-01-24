//
//  POISearchManager.swift
//  EarthLord
//
//  Created by Claude on 2026/1/14.
//  POI搜索管理器 - 使用MapKit搜索附近真实地点
//

import Foundation
import MapKit
import CoreLocation
import os.log

/// POI日志器
private let poiLog = OSLog(subsystem: "com.yanshuangren.EarthLord", category: "POI")

/// POI搜索错误
enum POISearchError: Error, LocalizedError {
    case noLocation
    case searchFailed(String)
    case noResults

    var errorDescription: String? {
        switch self {
        case .noLocation:
            return "无法获取当前位置"
        case .searchFailed(let message):
            return "搜索失败: \(message)"
        case .noResults:
            return "附近没有找到可探索的地点"
        }
    }
}

/// POI搜索管理器
/// 负责使用MKLocalSearch搜索附近的真实POI
@MainActor
class POISearchManager {

    // MARK: - Singleton

    static let shared = POISearchManager()

    // MARK: - Properties

    /// 搜索关键词和对应的游戏类型
    /// 使用自然语言搜索，在中国大陆更可靠
    private let searchQueries: [(query: String, type: POIGameType)] = [
        ("超市", .store),
        ("便利店", .store),
        ("商店", .store),
        ("医院", .hospital),
        ("诊所", .hospital),
        ("药店", .pharmacy),
        ("药房", .pharmacy),
        ("加油站", .gasStation),
        ("餐厅", .restaurant),
        ("饭店", .restaurant),
        ("咖啡", .cafe),
        ("奶茶", .cafe)
    ]

    /// 默认搜索半径（米）- 改为3公里
    private let defaultRadius: Double = 3000

    /// 默认最大返回POI数量
    private let defaultMaxPOICount: Int = 20

    // MARK: - Initialization

    private init() {
        print("🔍 [POISearchManager] 初始化完成")
        os_log("🔍 POISearchManager初始化", log: poiLog, type: .info)
    }

    // MARK: - Public Methods

    /// 搜索附近POI
    /// - Parameters:
    ///   - center: 搜索中心点坐标
    ///   - radiusMeters: 搜索半径（米），默认3000米
    ///   - maxCount: 最大返回数量（根据玩家密度动态调整）
    /// - Returns: 找到的POI列表
    func searchNearbyPOIs(
        center: CLLocationCoordinate2D,
        radiusMeters: Double? = nil,
        maxCount: Int? = nil
    ) async throws -> [ExplorablePOI] {

        let radius = radiusMeters ?? defaultRadius
        let maxPOICount = maxCount ?? defaultMaxPOICount

        print("═══════════════════════════════════════════════════")
        print("🔍 [POISearchManager] 开始搜索附近POI")
        print("   - 中心点: (\(center.latitude), \(center.longitude))")
        print("   - 搜索半径: \(radius) 米")
        print("   - 最大返回数量: \(maxPOICount) 个")
        print("   - 搜索关键词数量: \(searchQueries.count)")
        print("═══════════════════════════════════════════════════")
        os_log("🔍 开始搜索POI: (%{public}.6f, %{public}.6f) 半径%{public}.0fm",
               log: poiLog, type: .info, center.latitude, center.longitude, radius)

        var allPOIs: [ExplorablePOI] = []

        // 对每个搜索关键词进行搜索
        for (query, poiType) in searchQueries {
            do {
                let pois = try await searchWithQuery(
                    query: query,
                    center: center,
                    radius: radius,
                    poiType: poiType
                )
                allPOIs.append(contentsOf: pois)
                if !pois.isEmpty {
                    print("📍 [POISearchManager] \"\(query)\": 找到 \(pois.count) 个")
                    os_log("📍 搜索 '%{public}@': 找到%{public}d个",
                           log: poiLog, type: .info, query, pois.count)
                }
            } catch {
                print("⚠️ [POISearchManager] \"\(query)\" 搜索失败: \(error.localizedDescription)")
                os_log("⚠️ 搜索 '%{public}@' 失败: %{public}@",
                       log: poiLog, type: .error, query, error.localizedDescription)
                // 继续搜索其他关键词，不中断
            }
        }

        // 去重（基于坐标相近）
        let uniquePOIs = removeDuplicates(from: allPOIs)

        // 按距离排序
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let sortedPOIs = uniquePOIs.sorted {
            $0.distance(from: centerLocation) < $1.distance(from: centerLocation)
        }

        // 限制数量
        let limitedPOIs = Array(sortedPOIs.prefix(maxPOICount))

        print("═══════════════════════════════════════════════════")
        print("✅ [POISearchManager] 搜索完成")
        print("   - 总计找到: \(allPOIs.count) 个POI")
        print("   - 去重后: \(uniquePOIs.count) 个")
        print("   - 返回: \(limitedPOIs.count) 个")
        print("═══════════════════════════════════════════════════")
        os_log("✅ POI搜索完成: 找到%{public}d个, 去重后%{public}d个, 返回%{public}d个",
               log: poiLog, type: .info, allPOIs.count, uniquePOIs.count, limitedPOIs.count)

        // 打印POI列表
        for (index, poi) in limitedPOIs.enumerated() {
            let dist = poi.distance(from: centerLocation)
            print("   \(index + 1). \(poi.name) (\(poi.type.rawValue)) - \(Int(dist))m")
            os_log("   %{public}d. %{public}@ [%{public}@] %{public}.0fm",
                   log: poiLog, type: .info, index + 1, poi.name, poi.type.rawValue, dist)
        }

        if limitedPOIs.isEmpty {
            os_log("❌ 没有找到任何POI", log: poiLog, type: .error)
            throw POISearchError.noResults
        }

        return limitedPOIs
    }

    // MARK: - Private Methods

    /// 使用自然语言查询搜索POI
    private func searchWithQuery(
        query: String,
        center: CLLocationCoordinate2D,
        radius: Double,
        poiType: POIGameType
    ) async throws -> [ExplorablePOI] {

        // 创建搜索区域
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )

        // 创建搜索请求 - 使用自然语言查询
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        request.resultTypes = .pointOfInterest

        // 执行搜索
        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()

            // 转换为ExplorablePOI
            let pois = response.mapItems.compactMap { mapItem -> ExplorablePOI? in
                // 过滤掉超出半径的POI
                let coord = mapItem.placemark.coordinate
                let poiLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
                let distance = poiLocation.distance(from: centerLocation)

                guard distance <= radius else { return nil }

                let name = mapItem.name ?? "未知地点"

                // 生成稳定的POI ID（基于坐标和名称）
                let latStr = String(format: "%.5f", coord.latitude)
                let lonStr = String(format: "%.5f", coord.longitude)
                let stableId = "\(latStr)_\(lonStr)_\(name)".replacingOccurrences(of: " ", with: "_")

                // 使用传入的类型，而不是从category推断
                return ExplorablePOI(
                    id: stableId,
                    name: name,
                    type: poiType,
                    coordinate: coord,
                    isScavenged: false,
                    discoveredAt: Date()
                )
            }

            return pois
        } catch {
            throw POISearchError.searchFailed(error.localizedDescription)
        }
    }

    /// 去除重复的POI（基于坐标相近，50米内视为同一地点）
    private func removeDuplicates(from pois: [ExplorablePOI]) -> [ExplorablePOI] {
        var uniquePOIs: [ExplorablePOI] = []
        let duplicateThreshold: Double = 50 // 米

        for poi in pois {
            let poiLocation = CLLocation(
                latitude: poi.coordinate.latitude,
                longitude: poi.coordinate.longitude
            )

            // 检查是否与已有POI重复
            let isDuplicate = uniquePOIs.contains { existingPOI in
                let existingLocation = CLLocation(
                    latitude: existingPOI.coordinate.latitude,
                    longitude: existingPOI.coordinate.longitude
                )
                return poiLocation.distance(from: existingLocation) < duplicateThreshold
            }

            if !isDuplicate {
                uniquePOIs.append(poi)
            }
        }

        return uniquePOIs
    }
}
