//
//  BuildingDetailView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/26.
//  建筑详情视图
//

import SwiftUI

/// 建筑详情视图
/// 显示建筑的完整信息，包括描述、资源需求、建造时间等
struct BuildingDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let template: BuildingTemplate
    let onStartConstruction: (BuildingTemplate) -> Void

    @StateObject private var inventoryManager = InventoryManager.shared
    @State private var resourceCounts: [String: Int] = [:]
    @State private var isLoadingResources = true

    /// 检查资源是否全部足够
    var canBuild: Bool {
        for (resource, required) in template.requiredResources {
            if (resourceCounts[resource] ?? 0) < required {
                return false
            }
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 建筑头部
                    headerSection

                    // 建筑描述
                    descriptionSection

                    // 建筑属性
                    attributesSection

                    // 资源需求
                    resourcesSection

                    // 建造按钮
                    buildButton
                }
                .padding()
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .task {
                resourceCounts = await inventoryManager.getResourceCounts()
                isLoadingResources = false
            }
        }
    }

    // MARK: - 建筑头部

    private var headerSection: some View {
        HStack(spacing: 16) {
            // 建筑图标
            ZStack {
                Circle()
                    .fill(template.category.color.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: template.icon)
                    .font(.system(size: 36))
                    .foregroundColor(template.category.color)
            }

            VStack(alignment: .leading, spacing: 8) {
                // 名称
                Text(template.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                // 类别和阶段
                HStack(spacing: 8) {
                    // 类别标签
                    HStack(spacing: 4) {
                        Image(systemName: template.category.icon)
                            .font(.system(size: 12))
                        Text(template.category.displayName)
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(template.category.color.opacity(0.3))
                    )
                    .foregroundColor(template.category.color)

                    // 阶段标签
                    Text("T\(template.tier)")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(tierColor(template.tier).opacity(0.3))
                        )
                        .foregroundColor(tierColor(template.tier))
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - 建筑描述

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("描述")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text(template.description)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - 建筑属性

    private var attributesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("属性")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            HStack(spacing: 16) {
                // 建造时间
                AttributeItem(
                    icon: "clock.fill",
                    label: "建造时间",
                    value: formatBuildTime(template.buildTimeSeconds),
                    color: .blue
                )

                // 数量上限
                AttributeItem(
                    icon: "number",
                    label: "领地上限",
                    value: "\(template.maxPerTerritory) 个",
                    color: .orange
                )

                // 最高等级
                AttributeItem(
                    icon: "arrow.up.circle.fill",
                    label: "最高等级",
                    value: "Lv.\(template.maxLevel)",
                    color: .purple
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - 资源需求

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("所需资源")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if isLoadingResources {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if isLoadingResources {
                // 加载中占位
                ForEach(Array(template.requiredResources.keys), id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 44)
                }
            } else {
                // 资源列表
                ForEach(Array(template.requiredResources.keys.sorted()), id: \.self) { resource in
                    ResourceRow(
                        resourceId: resource,
                        required: template.requiredResources[resource] ?? 0,
                        available: resourceCounts[resource] ?? 0
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - 建造按钮

    private var buildButton: some View {
        Button {
            onStartConstruction(template)
        } label: {
            HStack {
                Image(systemName: "hammer.fill")
                Text("开始建造")
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
        .disabled(!canBuild || isLoadingResources)
    }

    // MARK: - 辅助方法

    private func formatBuildTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)秒"
        } else if seconds < 3600 {
            return "\(seconds / 60)分钟"
        } else {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            if minutes > 0 {
                return "\(hours)小时\(minutes)分"
            }
            return "\(hours)小时"
        }
    }

    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 1: return .green
        case 2: return .blue
        case 3: return .purple
        case 4: return .orange
        default: return .gray
        }
    }
}

// MARK: - 属性项组件

struct AttributeItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let mockTemplate = BuildingTemplate(
        id: UUID(),
        templateId: "shelter",
        name: "庇护所",
        tier: 1,
        category: .survival,
        description: "简易的遮风挡雨场所，提供基础防护。可以抵御恶劣天气，是末日生存的基础建筑。",
        icon: "house.fill",
        requiredResources: ["wood": 10, "cloth": 5],
        buildTimeSeconds: 180,
        maxPerTerritory: 1,
        maxLevel: 5
    )

    BuildingDetailView(template: mockTemplate) { _ in }
}
