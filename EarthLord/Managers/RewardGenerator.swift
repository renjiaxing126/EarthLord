//
//  RewardGenerator.swift
//  EarthLord
//
//  Created by Claude on 2026/1/13.
//  奖励生成器 - 根据行走距离生成奖励物品
//

import Foundation
import SwiftUI

/// 奖励等级
enum RewardTier: String, CaseIterable {
    case none = "无"
    case bronze = "铜级"
    case silver = "银级"
    case gold = "金级"
    case diamond = "钻石级"

    /// 等级图标
    var icon: String {
        switch self {
        case .none: return "xmark.circle"
        case .bronze: return "medal.fill"
        case .silver: return "medal.fill"
        case .gold: return "medal.fill"
        case .diamond: return "diamond.fill"
        }
    }

    /// 等级颜色
    var color: Color {
        switch self {
        case .none: return .gray
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .diamond: return Color(red: 0.6, green: 0.85, blue: 1.0)
        }
    }

    /// 物品数量
    var itemCount: Int {
        switch self {
        case .none: return 0
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .diamond: return 5
        }
    }

    /// 普通物品概率
    var commonProbability: Double {
        switch self {
        case .none: return 1.0
        case .bronze: return 0.90
        case .silver: return 0.70
        case .gold: return 0.50
        case .diamond: return 0.30
        }
    }

    /// 稀有物品概率
    var rareProbability: Double {
        switch self {
        case .none: return 0.0
        case .bronze: return 0.10
        case .silver: return 0.25
        case .gold: return 0.35
        case .diamond: return 0.40
        }
    }

    /// 史诗物品概率
    var epicProbability: Double {
        switch self {
        case .none: return 0.0
        case .bronze: return 0.0
        case .silver: return 0.05
        case .gold: return 0.15
        case .diamond: return 0.30
        }
    }
}

/// 物品稀有度
enum ItemRarity: String, CaseIterable, Codable {
    case common = "普通"
    case uncommon = "优秀"
    case rare = "稀有"
    case epic = "史诗"
    case legendary = "传奇"

    /// 稀有度颜色
    var color: Color {
        switch self {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    /// 从字符串初始化（支持英文值）
    init(from englishValue: String) {
        switch englishValue.lowercased() {
        case "common": self = .common
        case "uncommon": self = .uncommon
        case "rare": self = .rare
        case "epic": self = .epic
        case "legendary": self = .legendary
        default: self = .common
        }
    }
}

/// 奖励物品定义
struct RewardItemDefinition: Identifiable {
    let id: String
    let name: String
    let icon: String
    let rarity: ItemRarity
    let category: String
    let minQuantity: Int
    let maxQuantity: Int
}

/// 生成的奖励物品
struct GeneratedRewardItem: Identifiable, Codable {
    let id: String
    let itemId: String
    let name: String
    let icon: String
    let rarity: ItemRarity
    let quantity: Int
    let category: String       // 物品分类
    let isAIGenerated: Bool    // 是否AI生成
    let aiStory: String?       // AI背景故事

    /// 兼容旧代码的初始化器
    init(id: String, itemId: String, name: String, icon: String,
         rarity: ItemRarity, quantity: Int,
         category: String = "", isAIGenerated: Bool = false, aiStory: String? = nil) {
        self.id = id
        self.itemId = itemId
        self.name = name
        self.icon = icon
        self.rarity = rarity
        self.quantity = quantity
        self.category = category
        self.isAIGenerated = isAIGenerated
        self.aiStory = aiStory
    }
}

/// 奖励生成器
class RewardGenerator {

    // MARK: - Singleton

    static let shared = RewardGenerator()

    // MARK: - 物品池定义

    /// 普通物品池
    static let commonItems: [RewardItemDefinition] = [
        RewardItemDefinition(id: "water_bottle", name: "矿泉水", icon: "drop.fill", rarity: .common, category: "water", minQuantity: 1, maxQuantity: 3),
        RewardItemDefinition(id: "canned_food", name: "罐头", icon: "takeoutbag.and.cup.and.straw.fill", rarity: .common, category: "food", minQuantity: 1, maxQuantity: 2),
        RewardItemDefinition(id: "biscuit", name: "饼干", icon: "birthday.cake.fill", rarity: .common, category: "food", minQuantity: 1, maxQuantity: 3),
        RewardItemDefinition(id: "bandage", name: "绷带", icon: "bandage.fill", rarity: .common, category: "medical", minQuantity: 1, maxQuantity: 2),
        RewardItemDefinition(id: "wood", name: "木材", icon: "tree.fill", rarity: .common, category: "material", minQuantity: 2, maxQuantity: 5),
        RewardItemDefinition(id: "cloth", name: "布料", icon: "tshirt.fill", rarity: .common, category: "material", minQuantity: 1, maxQuantity: 3),
        RewardItemDefinition(id: "match", name: "火柴", icon: "flame.fill", rarity: .common, category: "tool", minQuantity: 1, maxQuantity: 5),
    ]

    /// 稀有物品池
    static let rareItems: [RewardItemDefinition] = [
        RewardItemDefinition(id: "first_aid_kit", name: "急救包", icon: "cross.case.fill", rarity: .rare, category: "medical", minQuantity: 1, maxQuantity: 1),
        RewardItemDefinition(id: "flashlight", name: "手电筒", icon: "flashlight.on.fill", rarity: .rare, category: "tool", minQuantity: 1, maxQuantity: 1),
        RewardItemDefinition(id: "radio", name: "收音机", icon: "radio.fill", rarity: .rare, category: "tool", minQuantity: 1, maxQuantity: 1),
        RewardItemDefinition(id: "toolbox", name: "工具箱", icon: "wrench.and.screwdriver.fill", rarity: .rare, category: "tool", minQuantity: 1, maxQuantity: 1),
        RewardItemDefinition(id: "medicine", name: "药品", icon: "pills.fill", rarity: .rare, category: "medical", minQuantity: 1, maxQuantity: 2),
        RewardItemDefinition(id: "rope", name: "绳索", icon: "lasso", rarity: .rare, category: "material", minQuantity: 1, maxQuantity: 2),
    ]

    /// 史诗物品池
    static let epicItems: [RewardItemDefinition] = [
        RewardItemDefinition(id: "antibiotic", name: "抗生素", icon: "syringe.fill", rarity: .epic, category: "medical", minQuantity: 1, maxQuantity: 1),
        RewardItemDefinition(id: "generator_part", name: "发电机零件", icon: "bolt.fill", rarity: .epic, category: "material", minQuantity: 1, maxQuantity: 1),
        RewardItemDefinition(id: "gas_mask", name: "防毒面具", icon: "allergens.fill", rarity: .epic, category: "tool", minQuantity: 1, maxQuantity: 1),
        RewardItemDefinition(id: "night_vision", name: "夜视仪", icon: "eye.fill", rarity: .epic, category: "tool", minQuantity: 1, maxQuantity: 1),
        RewardItemDefinition(id: "solar_panel", name: "太阳能板", icon: "sun.max.fill", rarity: .epic, category: "material", minQuantity: 1, maxQuantity: 1),
    ]

    // MARK: - Initialization

    private init() {
        print("🎁 RewardGenerator 初始化完成")
    }

    // MARK: - Public Methods

    /// 根据距离计算奖励等级
    /// - Parameter distance: 行走距离（米）
    /// - Returns: 奖励等级
    static func calculateTier(distance: Double) -> RewardTier {
        switch distance {
        case ..<200:
            return .none
        case 200..<500:
            return .bronze
        case 500..<1000:
            return .silver
        case 1000..<2000:
            return .gold
        default:
            return .diamond
        }
    }

    /// 计算距离下一等级还需要多少米
    /// - Parameter distance: 当前行走距离（米）
    /// - Returns: (下一等级, 还差多少米)，如果已是最高等级返回nil
    static func distanceToNextTier(distance: Double) -> (nextTier: RewardTier, remaining: Double)? {
        switch distance {
        case ..<200:
            return (.bronze, 200 - distance)
        case 200..<500:
            return (.silver, 500 - distance)
        case 500..<1000:
            return (.gold, 1000 - distance)
        case 1000..<2000:
            return (.diamond, 2000 - distance)
        default:
            return nil  // 已是最高等级
        }
    }

    /// 生成奖励物品
    /// - Parameter distance: 行走距离（米）
    /// - Returns: 奖励物品列表
    func generateRewards(distance: Double) -> [GeneratedRewardItem] {
        let tier = RewardGenerator.calculateTier(distance: distance)

        print("🎁 [RewardGenerator] 生成奖励: 距离=\(String(format: "%.1f", distance))m, 等级=\(tier.rawValue)")

        guard tier != .none else {
            print("⚠️ [RewardGenerator] 距离不足200米，无奖励")
            return []
        }

        var rewards: [GeneratedRewardItem] = []
        let itemCount = tier.itemCount

        for i in 0..<itemCount {
            // 掷骰子决定稀有度
            let rarity = rollRarity(tier: tier)
            print("🎲 [RewardGenerator] 第\(i+1)次抽奖，稀有度: \(rarity.rawValue)")

            // 从对应池中随机抽取物品
            if let item = pickRandomItem(rarity: rarity) {
                // 随机数量
                let quantity = Int.random(in: item.minQuantity...item.maxQuantity)

                let rewardItem = GeneratedRewardItem(
                    id: UUID().uuidString,
                    itemId: item.id,
                    name: item.name,
                    icon: item.icon,
                    rarity: item.rarity,
                    quantity: quantity
                )

                rewards.append(rewardItem)
                print("🎁 [RewardGenerator] 获得: \(item.name) x\(quantity) (\(rarity.rawValue))")
            }
        }

        // 合并相同物品
        let mergedRewards = mergeRewards(rewards)
        print("📦 [RewardGenerator] 合并后物品数: \(mergedRewards.count)")

        return mergedRewards
    }

    /// 将GeneratedRewardItem转换为旧的RewardItem格式（兼容ExplorationResultView）
    func convertToLegacyRewards(_ items: [GeneratedRewardItem]) -> [RewardItem] {
        return items.map { item in
            RewardItem(name: item.name, quantity: item.quantity, icon: item.icon)
        }
    }

    // MARK: - Private Methods

    /// 掷骰子决定稀有度
    private func rollRarity(tier: RewardTier) -> ItemRarity {
        let random = Double.random(in: 0..<1)

        if random < tier.epicProbability {
            return .epic
        } else if random < tier.epicProbability + tier.rareProbability {
            return .rare
        } else {
            return .common
        }
    }

    /// 从指定稀有度的物品池中随机抽取
    private func pickRandomItem(rarity: ItemRarity) -> RewardItemDefinition? {
        let pool: [RewardItemDefinition]

        switch rarity {
        case .common, .uncommon:
            // uncommon 也从普通池抽取（预设物品池只有3级）
            pool = RewardGenerator.commonItems
        case .rare:
            pool = RewardGenerator.rareItems
        case .epic, .legendary:
            // legendary 也从史诗池抽取（预设物品池只有3级）
            pool = RewardGenerator.epicItems
        }

        return pool.randomElement()
    }

    /// 合并相同物品
    private func mergeRewards(_ rewards: [GeneratedRewardItem]) -> [GeneratedRewardItem] {
        var merged: [String: GeneratedRewardItem] = [:]

        for reward in rewards {
            if let existing = merged[reward.itemId] {
                // 合并数量
                let newQuantity = existing.quantity + reward.quantity
                merged[reward.itemId] = GeneratedRewardItem(
                    id: existing.id,
                    itemId: existing.itemId,
                    name: existing.name,
                    icon: existing.icon,
                    rarity: existing.rarity,
                    quantity: newQuantity,
                    category: existing.category,
                    isAIGenerated: existing.isAIGenerated,
                    aiStory: existing.aiStory
                )
            } else {
                merged[reward.itemId] = reward
            }
        }

        return Array(merged.values)
    }
}
