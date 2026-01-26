//
//  BuildingManager.swift
//  EarthLord
//
//  Created by Claude on 2026/1/26.
//  建筑管理器 - 管理建筑建造、升级和状态
//

import Foundation
import Combine
import Supabase
import CoreLocation

/// 建筑管理器
/// 负责加载建筑模板、管理玩家建筑、处理建造和升级逻辑
@MainActor
class BuildingManager: ObservableObject {

    // MARK: - Singleton

    static let shared = BuildingManager()

    // MARK: - Published Properties

    /// 建筑模板列表
    @Published var buildingTemplates: [BuildingTemplate] = []

    /// 玩家建筑列表
    @Published var playerBuildings: [PlayerBuilding] = []

    /// 是否正在加载
    @Published var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    /// Supabase 服务
    private let supabase = SupabaseService.shared

    /// 建筑完成计时器
    private var buildingTimers: [UUID: Timer] = [:]

    // MARK: - Initialization

    private init() {
        print("🏗️ BuildingManager 初始化完成")
        loadTemplates()
    }

    // MARK: - Template Loading

    /// 从 Bundle JSON 加载建筑模板
    func loadTemplates() {
        guard let url = Bundle.main.url(forResource: "building_templates", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("❌ [BuildingManager] 无法加载 building_templates.json")
            return
        }

        do {
            let decoder = JSONDecoder()
            let wrapper = try decoder.decode(TemplateWrapper.self, from: data)
            buildingTemplates = wrapper.templates
            print("✅ [BuildingManager] 成功加载 \(buildingTemplates.count) 个建筑模板")
        } catch {
            print("❌ [BuildingManager] JSON 解析失败: \(error)")
        }
    }

    /// 模板包装结构
    private struct TemplateWrapper: Decodable {
        let version: String
        let templates: [BuildingTemplate]
    }

    // MARK: - Template Query

    /// 根据模板 ID 获取模板
    func getTemplate(by templateId: String) -> BuildingTemplate? {
        return buildingTemplates.first { $0.templateId == templateId }
    }

    /// 根据类别获取模板列表
    func getTemplates(by category: BuildingCategory) -> [BuildingTemplate] {
        return buildingTemplates.filter { $0.category == category }
    }

    /// 根据阶段获取模板列表
    func getTemplates(by tier: Int) -> [BuildingTemplate] {
        return buildingTemplates.filter { $0.tier == tier }
    }

    // MARK: - Build Validation

    /// 检查是否可以建造
    /// - Parameters:
    ///   - template: 建筑模板
    ///   - territoryId: 领地 ID
    /// - Returns: 是否可以建造及错误信息
    func canBuild(
        template: BuildingTemplate,
        territoryId: String
    ) async -> (canBuild: Bool, error: BuildingError?) {
        // 1. 获取玩家资源
        let playerResources = await InventoryManager.shared.getResourceCounts()

        // 2. 检查资源是否足够
        var insufficientResources: [String: Int] = [:]
        for (resource, required) in template.requiredResources {
            let available = playerResources[resource] ?? 0
            if available < required {
                insufficientResources[resource] = required - available
            }
        }
        if !insufficientResources.isEmpty {
            return (false, .insufficientResources(insufficientResources))
        }

        // 3. 检查数量是否达到上限
        let existingCount = playerBuildings.filter {
            $0.territoryId == territoryId &&
            $0.templateId == template.templateId
        }.count
        if existingCount >= template.maxPerTerritory {
            return (false, .maxBuildingsReached(template.maxPerTerritory))
        }

        return (true, nil)
    }

    // MARK: - Construction

    /// 开始建造
    /// - Parameters:
    ///   - templateId: 模板 ID
    ///   - territoryId: 领地 ID
    ///   - location: 建筑位置（可选）
    /// - Returns: 新建筑或错误
    func startConstruction(
        templateId: String,
        territoryId: String,
        location: CLLocationCoordinate2D? = nil
    ) async throws -> PlayerBuilding {
        print("🔨 [BuildingManager] 开始建造: \(templateId) 在领地 \(territoryId)")

        // 1. 获取模板
        guard let template = getTemplate(by: templateId) else {
            throw BuildingError.templateNotFound
        }

        // 2. 检查是否可以建造
        let (canBuild, error) = await canBuild(template: template, territoryId: territoryId)
        if !canBuild, let error = error {
            throw error
        }

        // 3. 扣除资源
        let success = await InventoryManager.shared.consumeResources(template.requiredResources)
        if !success {
            throw BuildingError.insufficientResources(template.requiredResources)
        }

        // 4. 获取当前用户
        guard let user = try? await supabase.auth.user() else {
            throw BuildingError.userNotLoggedIn
        }

        // 5. 创建建筑记录
        let newBuilding = InsertPlayerBuilding(
            userId: user.id.uuidString,
            territoryId: territoryId,
            templateId: templateId,
            buildingName: template.name,
            status: BuildingStatus.constructing.rawValue,
            level: 1,
            locationLat: location?.latitude,
            locationLon: location?.longitude
        )

        do {
            let inserted: [PlayerBuilding] = try await supabase
                .from("player_buildings")
                .insert(newBuilding)
                .select()
                .execute()
                .value

            guard let building = inserted.first else {
                throw BuildingError.databaseError("插入建筑失败")
            }

            // 6. 添加到本地列表
            playerBuildings.append(building)

            // 7. 设置完成计时器
            scheduleCompletionTimer(for: building, buildTime: template.buildTimeSeconds)

            print("✅ [BuildingManager] 建造开始: \(building.buildingName), 预计 \(template.buildTimeSeconds) 秒完成")
            return building

        } catch let error as BuildingError {
            throw error
        } catch {
            throw BuildingError.databaseError(error.localizedDescription)
        }
    }

    /// 完成建造
    /// - Parameter buildingId: 建筑 ID
    func completeConstruction(buildingId: UUID) async throws {
        print("🏠 [BuildingManager] 完成建造: \(buildingId)")

        // 1. 查找建筑
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.databaseError("建筑不存在")
        }

        // 2. 检查状态
        guard playerBuildings[index].status == .constructing else {
            throw BuildingError.invalidStatus
        }

        // 3. 更新数据库
        let updateData = UpdatePlayerBuilding(
            status: BuildingStatus.active.rawValue,
            level: nil,
            buildCompletedAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )

        do {
            try await supabase
                .from("player_buildings")
                .update(updateData)
                .eq("id", value: buildingId.uuidString)
                .execute()

            // 4. 更新本地状态
            playerBuildings[index].status = .active
            playerBuildings[index].buildCompletedAt = Date()

            // 5. 取消计时器
            buildingTimers[buildingId]?.invalidate()
            buildingTimers.removeValue(forKey: buildingId)

            print("✅ [BuildingManager] 建筑完成: \(playerBuildings[index].buildingName)")

        } catch {
            throw BuildingError.databaseError(error.localizedDescription)
        }
    }

    // MARK: - Upgrade

    /// 升级建筑
    /// - Parameter buildingId: 建筑 ID
    func upgradeBuilding(buildingId: UUID) async throws {
        print("⬆️ [BuildingManager] 升级建筑: \(buildingId)")

        // 1. 查找建筑
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.databaseError("建筑不存在")
        }

        let building = playerBuildings[index]

        // 2. 检查状态
        guard building.status == .active else {
            throw BuildingError.invalidStatus
        }

        // 3. 获取模板检查最大等级
        guard let template = getTemplate(by: building.templateId) else {
            throw BuildingError.templateNotFound
        }

        if building.level >= template.maxLevel {
            throw BuildingError.maxLevelReached
        }

        // 4. 计算升级所需资源（每级增加 50%）
        let multiplier = 1.0 + Double(building.level) * 0.5
        var upgradeResources: [String: Int] = [:]
        for (resource, amount) in template.requiredResources {
            upgradeResources[resource] = Int(Double(amount) * multiplier)
        }

        // 5. 检查并扣除资源
        let playerResources = await InventoryManager.shared.getResourceCounts()
        var insufficientResources: [String: Int] = [:]
        for (resource, required) in upgradeResources {
            let available = playerResources[resource] ?? 0
            if available < required {
                insufficientResources[resource] = required - available
            }
        }
        if !insufficientResources.isEmpty {
            throw BuildingError.insufficientResources(insufficientResources)
        }

        let success = await InventoryManager.shared.consumeResources(upgradeResources)
        if !success {
            throw BuildingError.insufficientResources(upgradeResources)
        }

        // 6. 更新数据库
        let newLevel = building.level + 1
        let updateData = UpdatePlayerBuilding(
            status: nil,
            level: newLevel,
            buildCompletedAt: nil,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )

        do {
            try await supabase
                .from("player_buildings")
                .update(updateData)
                .eq("id", value: buildingId.uuidString)
                .execute()

            // 7. 更新本地状态
            playerBuildings[index].level = newLevel

            print("✅ [BuildingManager] 建筑升级完成: \(building.buildingName) Lv.\(newLevel)")

        } catch {
            throw BuildingError.databaseError(error.localizedDescription)
        }
    }

    // MARK: - Demolish

    /// 拆除建筑
    /// - Parameter buildingId: 建筑 ID
    func demolishBuilding(buildingId: UUID) async throws {
        print("🗑️ [BuildingManager] 拆除建筑: \(buildingId)")

        // 1. 查找建筑
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.databaseError("建筑不存在")
        }

        let building = playerBuildings[index]

        // 2. 从数据库删除
        do {
            try await supabase
                .from("player_buildings")
                .delete()
                .eq("id", value: buildingId.uuidString)
                .execute()

            // 3. 从本地列表移除
            playerBuildings.remove(at: index)

            // 4. 取消计时器（如果有）
            buildingTimers[buildingId]?.invalidate()
            buildingTimers.removeValue(forKey: buildingId)

            print("✅ [BuildingManager] 建筑拆除成功: \(building.buildingName)")

            // 5. 发送通知
            NotificationCenter.default.post(name: .buildingUpdated, object: nil)

        } catch {
            throw BuildingError.databaseError(error.localizedDescription)
        }
    }

    // MARK: - Fetch Buildings

    /// 获取某领地的建筑
    /// - Parameter territoryId: 领地 ID
    func fetchPlayerBuildings(territoryId: String) async {
        isLoading = true
        errorMessage = nil

        print("📦 [BuildingManager] 加载领地建筑: \(territoryId)")

        do {
            let user = try await supabase.auth.user()

            let buildings: [PlayerBuilding] = try await supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: user.id.uuidString)
                .eq("territory_id", value: territoryId)
                .order("created_at", ascending: false)
                .execute()
                .value

            playerBuildings = buildings

            // 检查正在建造中的建筑，恢复计时器
            for building in buildings where building.status == .constructing {
                if let template = getTemplate(by: building.templateId) {
                    let elapsed = Date().timeIntervalSince(building.buildStartedAt)
                    let remaining = max(0, Double(template.buildTimeSeconds) - elapsed)
                    if remaining > 0 {
                        scheduleCompletionTimer(for: building, buildTime: Int(remaining))
                    } else {
                        // 已经超时，立即完成
                        try? await completeConstruction(buildingId: building.id)
                    }
                }
            }

            print("✅ [BuildingManager] 加载成功，共 \(buildings.count) 个建筑")

        } catch {
            errorMessage = "加载建筑失败: \(error.localizedDescription)"
            print("❌ [BuildingManager] 加载失败: \(error)")
        }

        isLoading = false
    }

    /// 获取所有玩家建筑
    func fetchAllPlayerBuildings() async {
        isLoading = true
        errorMessage = nil

        print("📦 [BuildingManager] 加载所有建筑")

        do {
            let user = try await supabase.auth.user()

            let buildings: [PlayerBuilding] = try await supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: user.id.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            playerBuildings = buildings
            print("✅ [BuildingManager] 加载成功，共 \(buildings.count) 个建筑")

        } catch {
            errorMessage = "加载建筑失败: \(error.localizedDescription)"
            print("❌ [BuildingManager] 加载失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - Timer Management

    /// 设置建造完成计时器
    private func scheduleCompletionTimer(for building: PlayerBuilding, buildTime: Int) {
        // 取消已有计时器
        buildingTimers[building.id]?.invalidate()

        // 创建新计时器
        let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(buildTime), repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                try? await self?.completeConstruction(buildingId: building.id)
            }
        }
        buildingTimers[building.id] = timer

        print("⏱️ [BuildingManager] 设置计时器: \(building.buildingName), \(buildTime) 秒后完成")
    }

    // MARK: - Helper Methods

    /// 获取建筑剩余建造时间
    func getRemainingBuildTime(for building: PlayerBuilding) -> TimeInterval? {
        guard building.status == .constructing,
              let template = getTemplate(by: building.templateId) else {
            return nil
        }

        let elapsed = Date().timeIntervalSince(building.buildStartedAt)
        let remaining = Double(template.buildTimeSeconds) - elapsed
        return max(0, remaining)
    }

    /// 获取某领地某类型建筑数量
    func getBuildingCount(templateId: String, territoryId: String) -> Int {
        return playerBuildings.filter {
            $0.templateId == templateId && $0.territoryId == territoryId
        }.count
    }
}
