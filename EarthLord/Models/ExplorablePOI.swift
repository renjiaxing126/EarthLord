//
//  ExplorablePOI.swift
//  EarthLord
//
//  Created by Claude on 2026/1/14.
//  可探索的POI模型 - 用于探索模式中的地点搜刮
//

import Foundation
import CoreLocation
import SwiftUI
import MapKit

/// POI游戏类型（映射Apple MapKit类型）
enum POIGameType: String, CaseIterable {
    case store = "商店"
    case hospital = "医院"
    case pharmacy = "药店"
    case gasStation = "加油站"
    case restaurant = "餐厅"
    case cafe = "咖啡店"
    case unknown = "未知地点"

    /// SF Symbols图标
    var icon: String {
        switch self {
        case .store: return "cart.fill"
        case .hospital: return "cross.case.fill"
        case .pharmacy: return "pills.fill"
        case .gasStation: return "fuelpump.fill"
        case .restaurant: return "fork.knife"
        case .cafe: return "cup.and.saucer.fill"
        case .unknown: return "mappin.circle.fill"
        }
    }

    /// 类型颜色
    var color: Color {
        switch self {
        case .store: return .green
        case .hospital: return .red
        case .pharmacy: return .purple
        case .gasStation: return .orange
        case .restaurant: return .yellow
        case .cafe: return .brown
        case .unknown: return .gray
        }
    }

    /// 搜刮等效距离（用于奖励计算）
    /// 不同类型POI给予不同等级奖励
    var equivalentDistance: Double {
        switch self {
        case .hospital: return 800    // 金级边缘
        case .pharmacy: return 600    // 银级
        case .store: return 500       // 银级
        case .gasStation: return 500  // 银级
        case .restaurant: return 400  // 铜级
        case .cafe: return 300        // 铜级
        case .unknown: return 300     // 铜级
        }
    }

    /// 危险值（决定AI物品稀有度分布）
    /// 1-5级，越高越危险，物品越稀有
    var dangerLevel: Int {
        switch self {
        case .cafe, .restaurant: return 1   // 低危：普通/优秀为主
        case .store: return 2               // 低危：普通/优秀为主
        case .gasStation: return 3          // 中危：可出稀有
        case .pharmacy: return 4            // 高危：稀有/史诗为主
        case .hospital: return 5            // 极危：史诗/传奇为主
        case .unknown: return 2
        }
    }

    /// 从MKPointOfInterestCategory转换
    static func from(category: MKPointOfInterestCategory?) -> POIGameType {
        guard let category = category else { return .unknown }

        switch category {
        case .store, .foodMarket:
            return .store
        case .hospital:
            return .hospital
        case .pharmacy:
            return .pharmacy
        case .gasStation, .evCharger:
            return .gasStation
        case .restaurant:
            return .restaurant
        case .cafe:
            return .cafe
        default:
            return .unknown
        }
    }
}

/// 可探索的POI模型
struct ExplorablePOI: Identifiable, Equatable {
    let id: String
    let name: String
    let type: POIGameType
    let coordinate: CLLocationCoordinate2D
    var isScavenged: Bool

    /// 创建时间（用于排序）
    let discoveredAt: Date

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        name: String,
        type: POIGameType,
        coordinate: CLLocationCoordinate2D,
        isScavenged: Bool = false,
        discoveredAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.coordinate = coordinate
        self.isScavenged = isScavenged
        self.discoveredAt = discoveredAt
    }

    /// 从MKMapItem创建
    /// 使用基于坐标和名称的稳定ID，确保同一POI在不同会话中有相同ID
    init(from mapItem: MKMapItem) {
        let name = mapItem.name ?? "未知地点"
        let coord = mapItem.placemark.coordinate
        // 使用坐标（精确到小数点后5位，约1米精度）和名称生成稳定ID
        let latStr = String(format: "%.5f", coord.latitude)
        let lonStr = String(format: "%.5f", coord.longitude)
        self.id = "\(latStr)_\(lonStr)_\(name)".replacingOccurrences(of: " ", with: "_")

        self.name = name
        self.type = POIGameType.from(category: mapItem.pointOfInterestCategory)
        self.coordinate = coord
        self.isScavenged = false
        self.discoveredAt = Date()
    }

    // MARK: - Methods

    /// 计算到指定位置的距离（米）
    func distance(from location: CLLocation) -> Double {
        let poiLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        return location.distance(from: poiLocation)
    }

    /// 格式化距离显示
    func formattedDistance(from location: CLLocation) -> String {
        let dist = distance(from: location)
        if dist >= 1000 {
            return String(format: "%.1f km", dist / 1000)
        } else {
            return String(format: "%.0f m", dist)
        }
    }

    // MARK: - Equatable

    static func == (lhs: ExplorablePOI, rhs: ExplorablePOI) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - POI Annotation (用于地图显示)

/// 自定义地图标注
class POIAnnotation: NSObject, MKAnnotation {
    let poi: ExplorablePOI

    var coordinate: CLLocationCoordinate2D {
        poi.coordinate
    }

    var title: String? {
        poi.name
    }

    var subtitle: String? {
        poi.type.rawValue
    }

    init(poi: ExplorablePOI) {
        self.poi = poi
        super.init()
    }
}
