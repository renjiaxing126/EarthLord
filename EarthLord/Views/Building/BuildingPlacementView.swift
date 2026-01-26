//
//  BuildingPlacementView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/26.
//  建造确认视图
//

import SwiftUI
import CoreLocation

/// 建造确认视图
/// 显示资源检查和地图位置选择
struct BuildingPlacementView: View {
    @Environment(\.dismiss) private var dismiss

    /// 建筑模板
    let template: BuildingTemplate

    /// 领地信息
    let territory: Territory

    /// 建造完成回调
    let onBuildComplete: () -> Void

    @StateObject private var buildingManager = BuildingManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared

    /// 选中的位置
    @State private var selectedLocation: CLLocationCoordinate2D?

    /// 位置是否有效
    @State private var isValidLocation = false

    /// 资源数量
    @State private var resourceCounts: [String: Int] = [:]

    /// 是否正在加载
    @State private var isLoading = true

    /// 是否正在建造
    @State private var isBuilding = false

    /// 错误信息
    @State private var errorMessage: String?

    /// 显示错误弹窗
    @State private var showError = false

    /// 领地坐标（GCJ-02）
    var territoryCoordinates: [CLLocationCoordinate2D] {
        territory.toCoordinates().map { coord in
            CoordinateConverter.wgs84ToGcj02(coord)
        }
    }

    /// 该领地的已有建筑
    var existingBuildings: [PlayerBuilding] {
        buildingManager.playerBuildings.filter { $0.territoryId == territory.id }
    }

    /// 资源是否足够
    var hasEnoughResources: Bool {
        for (resource, required) in template.requiredResources {
            if (resourceCounts[resource] ?? 0) < required {
                return false
            }
        }
        return true
    }

    /// 可以建造
    var canBuild: Bool {
        hasEnoughResources && isValidLocation && selectedLocation != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 地图选择器
                mapSection

                // 底部面板
                bottomPanel
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle("选择建造位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
            .task {
                await loadData()
            }
            .alert("建造失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
    }

    // MARK: - 地图部分

    private var mapSection: some View {
        ZStack {
            // 地图
            BuildingLocationPickerView(
                territoryCoordinates: territoryCoordinates,
                existingBuildings: existingBuildings,
                selectedLocation: $selectedLocation,
                isValidLocation: $isValidLocation
            )

            // 提示文字
            VStack {
                HStack {
                    Spacer()

                    Text(locationHintText)
                        .font(.system(size: 12))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(locationHintColor.opacity(0.9))
                        )
                        .foregroundColor(.white)
                        .padding()
                }

                Spacer()
            }
        }
    }

    /// 位置提示文字
    private var locationHintText: String {
        if selectedLocation == nil {
            return "点击地图选择建造位置"
        } else if isValidLocation {
            return "位置有效"
        } else {
            return "位置无效（需在领地内）"
        }
    }

    /// 位置提示颜色
    private var locationHintColor: Color {
        if selectedLocation == nil {
            return .gray
        } else if isValidLocation {
            return .green
        } else {
            return .red
        }
    }

    // MARK: - 底部面板

    private var bottomPanel: some View {
        VStack(spacing: 16) {
            // 建筑信息
            buildingInfoRow

            // 资源检查
            resourceCheckSection

            // 建造按钮
            buildButton
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(white: 0.12))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - 建筑信息行

    private var buildingInfoRow: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(template.category.color.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: template.icon)
                    .font(.system(size: 20))
                    .foregroundColor(template.category.color)
            }

            // 名称和描述
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text("建造时间: \(formatBuildTime(template.buildTimeSeconds))")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // 阶段标签
            Text("T\(template.tier)")
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.3))
                )
                .foregroundColor(.green)
        }
    }

    // MARK: - 资源检查部分

    private var resourceCheckSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("所需资源")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            if isLoading {
                // 加载占位
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 32)
                    }
                }
            } else {
                // 资源列表（横向紧凑布局）
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(template.requiredResources.keys.sorted()), id: \.self) { resource in
                            CompactResourceBadge(
                                resourceId: resource,
                                required: template.requiredResources[resource] ?? 0,
                                available: resourceCounts[resource] ?? 0
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - 建造按钮

    private var buildButton: some View {
        Button {
            Task {
                await startConstruction()
            }
        } label: {
            HStack {
                if isBuilding {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "hammer.fill")
                }
                Text(isBuilding ? "建造中..." : "确认建造")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canBuild ? ApocalypseTheme.primary : Color.gray)
            )
            .foregroundColor(.white)
        }
        .disabled(!canBuild || isBuilding)
    }

    // MARK: - 方法

    private func loadData() async {
        isLoading = true

        // 加载资源
        resourceCounts = await inventoryManager.getResourceCounts()

        // 加载该领地的建筑
        await buildingManager.fetchPlayerBuildings(territoryId: territory.id)

        isLoading = false
    }

    private func startConstruction() async {
        guard let location = selectedLocation else { return }

        isBuilding = true

        do {
            // 将 GCJ-02 坐标转回 WGS-84 存储
            let wgs84Location = CoordinateConverter.gcj02ToWgs84(location)

            _ = try await buildingManager.startConstruction(
                templateId: template.templateId,
                territoryId: territory.id,
                location: wgs84Location
            )

            print("✅ 建造开始成功")

            // 发送通知刷新
            NotificationCenter.default.post(name: .territoryUpdated, object: nil)

            // 回调并关闭
            onBuildComplete()
            dismiss()

        } catch {
            errorMessage = error.localizedDescription
            showError = true
            print("❌ 建造失败: \(error)")
        }

        isBuilding = false
    }

    private func formatBuildTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)秒"
        } else if seconds < 3600 {
            return "\(seconds / 60)分钟"
        } else {
            return "\(seconds / 3600)小时"
        }
    }
}

// MARK: - 紧凑资源徽章

struct CompactResourceBadge: View {
    let resourceId: String
    let required: Int
    let available: Int

    var isSufficient: Bool {
        available >= required
    }

    var resourceName: String {
        let nameMap: [String: String] = [
            "wood": "木材",
            "stone": "石头",
            "metal": "金属",
            "cloth": "布料",
            "glass": "玻璃",
            "wire": "电线",
            "seed": "种子"
        ]
        return nameMap[resourceId] ?? resourceId
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(resourceName)
                .font(.system(size: 11))

            Text("\(available)/\(required)")
                .font(.system(size: 11, weight: .bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isSufficient ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
        )
        .foregroundColor(isSufficient ? .green : .red)
    }
}

#Preview {
    let mockTemplate = BuildingTemplate(
        id: UUID(),
        templateId: "shelter",
        name: "庇护所",
        tier: 1,
        category: .survival,
        description: "简易的遮风挡雨场所",
        icon: "house.fill",
        requiredResources: ["wood": 10, "cloth": 5],
        buildTimeSeconds: 180,
        maxPerTerritory: 1,
        maxLevel: 5
    )

    let mockTerritory = Territory(
        id: "123",
        userId: "456",
        name: "测试领地",
        path: [["lat": 31.2, "lon": 121.4], ["lat": 31.21, "lon": 121.4], ["lat": 31.21, "lon": 121.41]],
        area: 10000,
        pointCount: 3,
        isActive: true,
        completedAt: nil,
        startedAt: nil,
        createdAt: nil
    )

    BuildingPlacementView(
        template: mockTemplate,
        territory: mockTerritory
    ) {}
}
