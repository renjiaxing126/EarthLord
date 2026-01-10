//
//  MockExplorationData.swift
//  EarthLord
//
//  Created by Claude on 2026/1/9.
//  探索模块测试假数据
//

import Foundation
import CoreLocation
import SwiftUI

// MARK: - POI 数据结构

/// POI 状态
enum POIStatus {
    case undiscovered   // 未发现
    case discovered     // 已发现
    case depleted       // 已被搜空
}

/// POI 类型
enum POIType: String, CaseIterable {
    case hospital = "医院"
    case supermarket = "超市"
    case factory = "工厂"
    case pharmacy = "药店"
    case gasStation = "加油站"

    /// 图标
    var icon: String {
        switch self {
        case .hospital: return "cross.case.fill"
        case .supermarket: return "cart.fill"
        case .factory: return "building.2.fill"
        case .pharmacy: return "pills.fill"
        case .gasStation: return "fuelpump.fill"
        }
    }

    /// 颜色
    var color: Color {
        switch self {
        case .hospital: return .red
        case .supermarket: return .green
        case .factory: return .gray
        case .pharmacy: return .purple
        case .gasStation: return .orange
        }
    }
}

/// POI 兴趣点
struct POI: Identifiable {
    let id: String
    let name: String                    // POI 名称
    let type: POIType                   // POI 类型
    let coordinate: CLLocationCoordinate2D  // 坐标
    let status: POIStatus               // 状态
    let hasResources: Bool              // 是否有物资
    let description: String             // 描述
    let distanceFromUser: Double?       // 距离用户的距离（米）
}

// MARK: - 背包物品数据结构

/// 物品品质
enum ItemQuality: String, CaseIterable {
    case common = "普通"
    case uncommon = "优良"
    case rare = "稀有"
    case epic = "史诗"

    /// 稀有度颜色
    var color: Color {
        switch self {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        }
    }
}

/// 物品类型
enum ItemType: String, CaseIterable {
    case water = "水"
    case food = "食物"
    case medical = "医疗"
    case material = "材料"
    case tool = "工具"

    /// 图标
    var icon: String {
        switch self {
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .medical: return "cross.case.fill"
        case .material: return "cube.box.fill"
        case .tool: return "wrench.and.screwdriver.fill"
        }
    }

    /// 颜色
    var color: Color {
        switch self {
        case .water: return .cyan
        case .food: return .orange
        case .medical: return .red
        case .material: return .brown
        case .tool: return .gray
        }
    }
}

/// 背包物品
struct BackpackItem: Identifiable {
    let id: String
    let name: String            // 物品名称
    let type: ItemType          // 物品类型
    let quantity: Int           // 数量
    let weight: Double          // 单个重量（kg）
    let quality: ItemQuality?   // 品质（部分物品没有品质）
    let icon: String            // SF Symbol 图标名
}

// MARK: - 物品定义表

/// 物品定义（游戏配置表）
struct ItemDefinition {
    let id: String
    let name: String            // 中文名
    let type: ItemType          // 分类
    let weight: Double          // 重量（kg）
    let volume: Double          // 体积（升）
    let rarity: ItemQuality     // 稀有度
    let icon: String            // 图标
    let description: String     // 描述
}

// MARK: - 探索结果数据结构

/// 探索统计
struct ExplorationStats {
    // 本次探索
    let walkDistance: Double        // 行走距离（米）
    let exploredArea: Double        // 探索面积（平方米）
    let explorationTime: TimeInterval  // 探索时长（秒）

    // 累计数据
    let totalWalkDistance: Double   // 累计行走距离（米）
    let totalExploredArea: Double   // 累计探索面积（平方米）

    // 排名
    let distanceRank: Int           // 距离排名
    let areaRank: Int               // 面积排名
}

/// 探索收获
struct ExplorationReward {
    let items: [RewardItem]         // 获得的物品列表
}

/// 收获物品
struct RewardItem {
    let name: String
    let quantity: Int
    let icon: String
}

// MARK: - Mock 测试数据

/// 探索模块测试假数据
class MockExplorationData {

    // MARK: - 1. POI 测试数据（5个不同状态的兴趣点）

    static let mockPOIs: [POI] = [
        POI(
            id: "poi_1",
            name: "废弃超市",
            type: .supermarket,
            coordinate: CLLocationCoordinate2D(latitude: 29.646500, longitude: 106.557800),
            status: .discovered,
            hasResources: true,
            description: "一座被遗弃的超市，货架上可能还有残留物资",
            distanceFromUser: 85.0
        ),
        POI(
            id: "poi_2",
            name: "医院废墟",
            type: .hospital,
            coordinate: CLLocationCoordinate2D(latitude: 29.646300, longitude: 106.557500),
            status: .depleted,
            hasResources: false,
            description: "曾经的医疗中心，现已被搜刮一空",
            distanceFromUser: 120.0
        ),
        POI(
            id: "poi_3",
            name: "加油站",
            type: .gasStation,
            coordinate: CLLocationCoordinate2D(latitude: 29.646800, longitude: 106.558000),
            status: .undiscovered,
            hasResources: true,
            description: "废弃的加油站，可能有燃料和工具",
            distanceFromUser: 250.0
        ),
        POI(
            id: "poi_4",
            name: "药店废墟",
            type: .pharmacy,
            coordinate: CLLocationCoordinate2D(latitude: 29.646100, longitude: 106.557300),
            status: .discovered,
            hasResources: true,
            description: "废弃的药店，药品可能还有保质期内的",
            distanceFromUser: 95.0
        ),
        POI(
            id: "poi_5",
            name: "工厂废墟",
            type: .factory,
            coordinate: CLLocationCoordinate2D(latitude: 29.647000, longitude: 106.558200),
            status: .undiscovered,
            hasResources: true,
            description: "荒废的工厂，可能有工具和原材料",
            distanceFromUser: 320.0
        )
    ]

    // MARK: - 2. 背包物品测试数据（6-8种不同类型）

    static let mockBackpackItems: [BackpackItem] = [
        // 水类
        BackpackItem(
            id: "item_1",
            name: "矿泉水",
            type: .water,
            quantity: 8,
            weight: 0.5,
            quality: nil,  // 水没有品质
            icon: "drop.fill"
        ),

        // 食物类
        BackpackItem(
            id: "item_2",
            name: "罐头食品",
            type: .food,
            quantity: 12,
            weight: 0.4,
            quality: .common,
            icon: "fork.knife"
        ),

        // 医疗类
        BackpackItem(
            id: "item_3",
            name: "绷带",
            type: .medical,
            quantity: 15,
            weight: 0.05,
            quality: .common,
            icon: "bandage.fill"
        ),
        BackpackItem(
            id: "item_4",
            name: "药品",
            type: .medical,
            quantity: 6,
            weight: 0.1,
            quality: .uncommon,
            icon: "cross.case.fill"
        ),

        // 材料类
        BackpackItem(
            id: "item_5",
            name: "木材",
            type: .material,
            quantity: 20,
            weight: 0.8,
            quality: .common,
            icon: "tree.fill"
        ),
        BackpackItem(
            id: "item_6",
            name: "废金属",
            type: .material,
            quantity: 10,
            weight: 1.2,
            quality: .uncommon,
            icon: "gearshape.2.fill"
        ),

        // 工具类
        BackpackItem(
            id: "item_7",
            name: "手电筒",
            type: .tool,
            quantity: 2,
            weight: 0.3,
            quality: .uncommon,
            icon: "flashlight.on.fill"
        ),
        BackpackItem(
            id: "item_8",
            name: "绳子",
            type: .tool,
            quantity: 5,
            weight: 0.2,
            quality: .common,
            icon: "link"
        )
    ]

    // MARK: - 3. 物品定义表（游戏配置）

    static let itemDefinitions: [ItemDefinition] = [
        ItemDefinition(
            id: "def_water",
            name: "矿泉水",
            type: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            icon: "drop.fill",
            description: "清洁的饮用水，生存必需品"
        ),
        ItemDefinition(
            id: "def_canned_food",
            name: "罐头食品",
            type: .food,
            weight: 0.4,
            volume: 0.3,
            rarity: .common,
            icon: "fork.knife",
            description: "密封罐头，保质期长，能提供能量"
        ),
        ItemDefinition(
            id: "def_bandage",
            name: "绷带",
            type: .medical,
            weight: 0.05,
            volume: 0.05,
            rarity: .common,
            icon: "bandage.fill",
            description: "基础医疗用品，用于包扎伤口"
        ),
        ItemDefinition(
            id: "def_medicine",
            name: "药品",
            type: .medical,
            weight: 0.1,
            volume: 0.1,
            rarity: .uncommon,
            icon: "cross.case.fill",
            description: "各类药品，能治疗疾病和伤痛"
        ),
        ItemDefinition(
            id: "def_wood",
            name: "木材",
            type: .material,
            weight: 0.8,
            volume: 1.0,
            rarity: .common,
            icon: "tree.fill",
            description: "基础建筑材料，可用于制作和建造"
        ),
        ItemDefinition(
            id: "def_scrap_metal",
            name: "废金属",
            type: .material,
            weight: 1.2,
            volume: 0.5,
            rarity: .uncommon,
            icon: "gearshape.2.fill",
            description: "废弃金属零件，可用于修理和制作工具"
        ),
        ItemDefinition(
            id: "def_flashlight",
            name: "手电筒",
            type: .tool,
            weight: 0.3,
            volume: 0.2,
            rarity: .uncommon,
            icon: "flashlight.on.fill",
            description: "照明工具，在夜间探索时非常有用"
        ),
        ItemDefinition(
            id: "def_rope",
            name: "绳子",
            type: .tool,
            weight: 0.2,
            volume: 0.15,
            rarity: .common,
            icon: "link",
            description: "实用的工具，可用于捆绑和攀爬"
        )
    ]

    // MARK: - 4. 探索结果示例

    static let mockExplorationResult: (stats: ExplorationStats, reward: ExplorationReward) = {
        let stats = ExplorationStats(
            // 本次探索
            walkDistance: 2500.0,           // 本次行走 2500 米
            exploredArea: 50000.0,          // 本次探索 5 万平方米
            explorationTime: 30 * 60,       // 探索时长 30 分钟

            // 累计数据
            totalWalkDistance: 15000.0,     // 累计行走 15000 米
            totalExploredArea: 250000.0,    // 累计探索 25 万平方米

            // 排名
            distanceRank: 42,               // 距离排名第 42
            areaRank: 38                    // 面积排名第 38
        )

        let reward = ExplorationReward(
            items: [
                RewardItem(name: "木材", quantity: 5, icon: "tree.fill"),
                RewardItem(name: "矿泉水", quantity: 3, icon: "drop.fill"),
                RewardItem(name: "罐头食品", quantity: 2, icon: "fork.knife")
            ]
        )

        return (stats, reward)
    }()

    // MARK: - 辅助方法

    /// 计算背包总重量
    static func calculateTotalWeight(items: [BackpackItem]) -> Double {
        return items.reduce(0.0) { total, item in
            total + (item.weight * Double(item.quantity))
        }
    }

    /// 根据类型筛选物品
    static func filterItems(by type: ItemType, from items: [BackpackItem]) -> [BackpackItem] {
        return items.filter { $0.type == type }
    }

    /// 获取未发现的 POI
    static func getUndiscoveredPOIs() -> [POI] {
        return mockPOIs.filter { $0.status == .undiscovered }
    }

    /// 获取有物资的 POI
    static func getPOIsWithResources() -> [POI] {
        return mockPOIs.filter { $0.hasResources }
    }
}
