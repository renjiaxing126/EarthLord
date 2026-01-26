//
//  BuildingCard.swift
//  EarthLord
//
//  Created by Claude on 2026/1/26.
//  建筑卡片组件
//

import SwiftUI

/// 建筑卡片组件（用于建筑浏览器）
struct BuildingCard: View {
    let template: BuildingTemplate
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // 顶部：图标和阶段
                HStack {
                    // 建筑图标
                    ZStack {
                        Circle()
                            .fill(template.category.color.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: template.icon)
                            .font(.system(size: 20))
                            .foregroundColor(template.category.color)
                    }

                    Spacer()

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

                // 建筑名称
                Text(template.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                // 建筑描述
                Text(template.description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
                    .frame(height: 32, alignment: .top)

                // 资源需求
                HStack(spacing: 6) {
                    ForEach(Array(template.requiredResources.prefix(3)), id: \.key) { resource, amount in
                        ResourceBadge(resourceId: resource, amount: amount)
                    }
                    if template.requiredResources.count > 3 {
                        Text("+\(template.requiredResources.count - 3)")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                // 底部信息
                HStack {
                    // 建造时间
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text(formatBuildTime(template.buildTimeSeconds))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.white.opacity(0.5))

                    Spacer()

                    // 数量限制
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.system(size: 10))
                        Text("限\(template.maxPerTerritory)个")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// 格式化建造时间
    private func formatBuildTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)秒"
        } else if seconds < 3600 {
            return "\(seconds / 60)分钟"
        } else {
            return "\(seconds / 3600)小时"
        }
    }

    /// 阶段颜色
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

// MARK: - BuildingCategory 颜色扩展

extension BuildingCategory {
    var color: Color {
        switch self {
        case .survival: return .green
        case .storage: return .blue
        case .production: return .orange
        case .energy: return .yellow
        }
    }
}

#Preview {
    let mockTemplate = BuildingTemplate(
        id: UUID(),
        templateId: "shelter",
        name: "庇护所",
        tier: 1,
        category: .survival,
        description: "简易的遮风挡雨场所，提供基础防护",
        icon: "house.fill",
        requiredResources: ["wood": 10, "cloth": 5],
        buildTimeSeconds: 180,
        maxPerTerritory: 1,
        maxLevel: 5
    )

    BuildingCard(template: mockTemplate) {}
        .frame(width: 180)
        .padding()
        .background(ApocalypseTheme.background)
}
