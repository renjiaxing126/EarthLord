//
//  AIItemGenerator.swift
//  EarthLord
//
//  Created by Claude on 2026/1/18.
//  AI物品生成器 - 调用Edge Function生成POI搜刮物品
//

import Foundation
import Supabase

// MARK: - Request Models

/// AI物品生成请求
struct AIItemRequest: Encodable {
    let poi: POIInfo
    let itemCount: Int

    struct POIInfo: Encodable {
        let name: String
        let type: String
        let dangerLevel: Int
    }
}

// MARK: - Response Models

/// AI物品生成响应
struct AIItemResponse: Decodable {
    let success: Bool
    let items: [AIGeneratedItem]?
    let error: String?
}

/// AI生成的单个物品
struct AIGeneratedItem: Decodable {
    let name: String
    let category: String
    let rarity: String
    let story: String
}

// MARK: - AIItemGenerator

/// AI物品生成器
/// 调用Supabase Edge Function生成具有故事背景的物品
@MainActor
class AIItemGenerator {

    // MARK: - Singleton

    static let shared = AIItemGenerator()

    // MARK: - Private Properties

    /// Supabase客户端
    private let supabase = SupabaseService.shared

    /// 请求超时时间（秒）
    private let requestTimeout: TimeInterval = 15.0

    // MARK: - Initialization

    private init() {
        print("🤖 AIItemGenerator 初始化完成")
    }

    // MARK: - Public Methods

    /// 为POI生成AI物品
    /// - Parameters:
    ///   - poi: 可探索的POI
    ///   - itemCount: 物品数量（可选，默认根据危险等级自动计算）
    /// - Returns: 生成的奖励物品列表
    func generateItems(for poi: ExplorablePOI, itemCount: Int? = nil) async -> [GeneratedRewardItem] {
        let dangerLevel = poi.type.dangerLevel
        let count = itemCount ?? calculateItemCount(dangerLevel: dangerLevel)

        print("═══════════════════════════════════════════════════")
        print("🤖 [AIItemGenerator] 开始生成AI物品")
        print("   - POI: \(poi.name) [\(poi.type.rawValue)]")
        print("   - 危险等级: \(dangerLevel)")
        print("   - 物品数量: \(count)")
        print("═══════════════════════════════════════════════════")

        do {
            // 获取当前session
            let session = try await supabase.auth.session

            // 构建请求体
            let request = AIItemRequest(
                poi: AIItemRequest.POIInfo(
                    name: poi.name,
                    type: poi.type.rawValue,
                    dangerLevel: dangerLevel
                ),
                itemCount: count
            )

            // 调用Edge Function
            let response: AIItemResponse = try await supabase.functions.invoke(
                "generate-ai-item",
                options: FunctionInvokeOptions(
                    headers: ["Authorization": "Bearer \(session.accessToken)"],
                    body: request
                )
            )

            // 检查响应
            if response.success, let items = response.items {
                print("✅ [AIItemGenerator] AI生成成功，共 \(items.count) 件物品")

                // 转换为GeneratedRewardItem
                let rewards = items.map { item -> GeneratedRewardItem in
                    let rarity = ItemRarity(from: item.rarity)
                    let icon = mapCategoryToIcon(item.category)

                    print("   - \(item.name) [\(rarity.rawValue)] - \(item.category)")

                    return GeneratedRewardItem(
                        id: UUID().uuidString,
                        itemId: generateItemId(name: item.name, category: item.category),
                        name: item.name,
                        icon: icon,
                        rarity: rarity,
                        quantity: 1,
                        category: item.category,
                        isAIGenerated: true,
                        aiStory: item.story
                    )
                }

                print("═══════════════════════════════════════════════════")
                return rewards
            } else {
                // API返回错误
                let errorMsg = response.error ?? "未知错误"
                print("⚠️ [AIItemGenerator] API返回错误: \(errorMsg)")
                print("⚠️ [AIItemGenerator] 降级到本地生成")
                return fallbackToLocalGeneration(for: poi)
            }

        } catch {
            // 网络或解析错误
            print("❌ [AIItemGenerator] 请求失败: \(error.localizedDescription)")
            print("❌ [AIItemGenerator] 错误详情: \(error)")
            print("⚠️ [AIItemGenerator] 降级到本地生成")
            return fallbackToLocalGeneration(for: poi)
        }
    }

    // MARK: - Private Methods

    /// 根据危险等级计算物品数量
    /// - Parameter dangerLevel: 危险等级 (1-5)
    /// - Returns: 物品数量
    private func calculateItemCount(dangerLevel: Int) -> Int {
        switch dangerLevel {
        case 1, 2: return 2
        case 3: return 3
        case 4: return 4
        case 5: return 5
        default: return 2
        }
    }

    /// 降级方案：使用本地生成器
    /// - Parameter poi: POI信息
    /// - Returns: 本地生成的物品
    private func fallbackToLocalGeneration(for poi: ExplorablePOI) -> [GeneratedRewardItem] {
        print("🔄 [AIItemGenerator] 使用本地生成器 (RewardGenerator)")
        let rewards = RewardGenerator.shared.generateRewards(distance: poi.type.equivalentDistance)
        print("✅ [AIItemGenerator] 本地生成完成，共 \(rewards.count) 件物品")
        print("═══════════════════════════════════════════════════")
        return rewards
    }

    /// 将物品分类映射到SF Symbol图标
    /// - Parameter category: 物品分类
    /// - Returns: SF Symbol名称
    private func mapCategoryToIcon(_ category: String) -> String {
        let categoryLower = category.lowercased()

        // 医疗类
        if categoryLower.contains("医") || categoryLower.contains("药") ||
           categoryLower.contains("medical") || categoryLower.contains("health") ||
           categoryLower.contains("急救") || categoryLower.contains("绷带") {
            return "cross.case.fill"
        }

        // 食物类
        if categoryLower.contains("食") || categoryLower.contains("food") ||
           categoryLower.contains("罐头") || categoryLower.contains("饼干") ||
           categoryLower.contains("营养") {
            return "fork.knife"
        }

        // 饮料/水类
        if categoryLower.contains("水") || categoryLower.contains("饮") ||
           categoryLower.contains("water") || categoryLower.contains("drink") {
            return "drop.fill"
        }

        // 工具类
        if categoryLower.contains("工具") || categoryLower.contains("tool") ||
           categoryLower.contains("修理") || categoryLower.contains("扳手") {
            return "wrench.and.screwdriver.fill"
        }

        // 电子类
        if categoryLower.contains("电") || categoryLower.contains("电子") ||
           categoryLower.contains("electronic") || categoryLower.contains("收音机") ||
           categoryLower.contains("手电") {
            return "bolt.fill"
        }

        // 燃料类
        if categoryLower.contains("燃料") || categoryLower.contains("汽油") ||
           categoryLower.contains("fuel") || categoryLower.contains("油") {
            return "fuelpump.fill"
        }

        // 材料类
        if categoryLower.contains("材料") || categoryLower.contains("material") ||
           categoryLower.contains("木") || categoryLower.contains("布") ||
           categoryLower.contains("绳") {
            return "shippingbox.fill"
        }

        // 防护类
        if categoryLower.contains("防护") || categoryLower.contains("护具") ||
           categoryLower.contains("protect") || categoryLower.contains("面具") {
            return "shield.fill"
        }

        // 武器类
        if categoryLower.contains("武器") || categoryLower.contains("weapon") ||
           categoryLower.contains("刀") || categoryLower.contains("棍") {
            return "hammer.fill"
        }

        // 照明类
        if categoryLower.contains("照明") || categoryLower.contains("light") ||
           categoryLower.contains("灯") || categoryLower.contains("火") {
            return "flashlight.on.fill"
        }

        // 通讯类
        if categoryLower.contains("通讯") || categoryLower.contains("通信") ||
           categoryLower.contains("communication") {
            return "antenna.radiowaves.left.and.right"
        }

        // 默认图标
        return "cube.fill"
    }

    /// 生成物品ID
    /// - Parameters:
    ///   - name: 物品名称
    ///   - category: 物品分类
    /// - Returns: 唯一的物品ID
    private func generateItemId(name: String, category: String) -> String {
        // 使用名称的拼音/简化版本 + 时间戳生成唯一ID
        let sanitizedName = name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "「", with: "")
            .replacingOccurrences(of: "」", with: "")
            .prefix(20)

        let timestamp = Int(Date().timeIntervalSince1970 * 1000) % 100000
        return "ai_\(sanitizedName)_\(timestamp)"
    }
}
