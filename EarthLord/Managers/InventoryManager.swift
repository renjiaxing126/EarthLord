//
//  InventoryManager.swift
//  EarthLord
//
//  Created by Claude on 2026/1/13.
//  背包管理器 - 管理背包数据，与Supabase同步
//

import Foundation
import Combine
import Supabase

/// 背包物品模型（数据库表映射）
struct InventoryItem: Codable, Identifiable {
    let id: String
    let userId: String
    let itemId: String
    var quantity: Int
    let obtainedAt: Date
    let source: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemId = "item_id"
        case quantity
        case obtainedAt = "obtained_at"
        case source
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// 用于插入的背包物品模型
struct InsertInventoryItem: Codable {
    let userId: String
    let itemId: String
    let quantity: Int
    let source: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case itemId = "item_id"
        case quantity
        case source
    }
}

/// 用于更新数量的模型
struct UpdateInventoryQuantity: Codable {
    let quantity: Int
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case quantity
        case updatedAt = "updated_at"
    }
}

/// 背包管理器
/// 负责管理背包数据，与Supabase数据库同步
@MainActor
class InventoryManager: ObservableObject {

    // MARK: - Singleton

    static let shared = InventoryManager()

    // MARK: - Published Properties

    /// 背包物品列表
    @Published var items: [InventoryItem] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    /// Supabase客户端
    private let supabase = SupabaseService.shared

    // MARK: - Initialization

    private init() {
        print("🎒 InventoryManager 初始化完成")
    }

    // MARK: - Public Methods

    /// 加载背包物品
    func loadInventory() async {
        isLoading = true
        errorMessage = nil

        print("📦 [InventoryManager] 开始加载背包物品")

        do {
            // 获取当前用户
            let user = try await supabase.auth.user()

            // 查询背包物品
            let response: [InventoryItem] = try await supabase
                .from("inventory_items")
                .select()
                .eq("user_id", value: user.id.uuidString)
                .order("obtained_at", ascending: false)
                .execute()
                .value

            items = response
            print("✅ [InventoryManager] 加载成功，共 \(items.count) 种物品")

        } catch {
            errorMessage = "加载背包失败: \(error.localizedDescription)"
            print("❌ [InventoryManager] 加载失败: \(error)")
        }

        isLoading = false
    }

    /// 添加物品到背包
    /// - Parameters:
    ///   - rewards: 奖励物品列表
    ///   - source: 来源（默认exploration）
    func addItems(_ rewards: [GeneratedRewardItem], source: String = "exploration") async {
        print("➕ [InventoryManager] 添加 \(rewards.count) 种物品到背包")

        do {
            // 获取当前用户
            let user = try await supabase.auth.user()

            for reward in rewards {
                // 检查是否已存在该物品
                let existing: [InventoryItem] = try await supabase
                    .from("inventory_items")
                    .select()
                    .eq("user_id", value: user.id.uuidString)
                    .eq("item_id", value: reward.itemId)
                    .execute()
                    .value

                if let existingItem = existing.first {
                    // 已存在，更新数量
                    let newQuantity = existingItem.quantity + reward.quantity
                    let updateData = UpdateInventoryQuantity(
                        quantity: newQuantity,
                        updatedAt: ISO8601DateFormatter().string(from: Date())
                    )

                    try await supabase
                        .from("inventory_items")
                        .update(updateData)
                        .eq("id", value: existingItem.id)
                        .execute()

                    print("📝 [InventoryManager] 更新物品: \(reward.name) +\(reward.quantity) -> 总计 \(newQuantity)")
                } else {
                    // 不存在，插入新记录
                    let newItem = InsertInventoryItem(
                        userId: user.id.uuidString,
                        itemId: reward.itemId,
                        quantity: reward.quantity,
                        source: source
                    )

                    try await supabase
                        .from("inventory_items")
                        .insert(newItem)
                        .execute()

                    print("✨ [InventoryManager] 新增物品: \(reward.name) x\(reward.quantity)")
                }
            }

            // 重新加载背包
            await loadInventory()

            print("✅ [InventoryManager] 物品添加完成")

        } catch {
            errorMessage = "添加物品失败: \(error.localizedDescription)"
            print("❌ [InventoryManager] 添加物品失败: \(error)")
        }
    }

    /// 移除物品
    /// - Parameters:
    ///   - itemId: 物品ID
    ///   - quantity: 移除数量
    func removeItem(itemId: String, quantity: Int) async {
        print("➖ [InventoryManager] 移除物品: \(itemId) x\(quantity)")

        do {
            // 获取当前用户
            let user = try await supabase.auth.user()

            // 查询该物品
            let existing: [InventoryItem] = try await supabase
                .from("inventory_items")
                .select()
                .eq("user_id", value: user.id.uuidString)
                .eq("item_id", value: itemId)
                .execute()
                .value

            guard let item = existing.first else {
                print("⚠️ [InventoryManager] 物品不存在: \(itemId)")
                return
            }

            if item.quantity <= quantity {
                // 数量不足，删除整条记录
                try await supabase
                    .from("inventory_items")
                    .delete()
                    .eq("id", value: item.id)
                    .execute()

                print("🗑️ [InventoryManager] 删除物品记录: \(itemId)")
            } else {
                // 减少数量
                let newQuantity = item.quantity - quantity
                let updateData = UpdateInventoryQuantity(
                    quantity: newQuantity,
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                )

                try await supabase
                    .from("inventory_items")
                    .update(updateData)
                    .eq("id", value: item.id)
                    .execute()

                print("📝 [InventoryManager] 减少物品: \(itemId) -\(quantity) -> 剩余 \(newQuantity)")
            }

            // 重新加载背包
            await loadInventory()

        } catch {
            errorMessage = "移除物品失败: \(error.localizedDescription)"
            print("❌ [InventoryManager] 移除物品失败: \(error)")
        }
    }

    /// 获取物品定义（根据itemId查找物品详细信息）
    func getItemDefinition(itemId: String) -> RewardItemDefinition? {
        // 从所有物品池中查找
        let allItems = RewardGenerator.commonItems + RewardGenerator.rareItems + RewardGenerator.epicItems
        return allItems.first { $0.id == itemId }
    }

    /// 计算背包总物品数量
    var totalItemCount: Int {
        items.reduce(0) { $0 + $1.quantity }
    }

    /// 计算背包物品种类数
    var itemTypeCount: Int {
        items.count
    }
}
