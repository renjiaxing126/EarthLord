//
//  ResourceRow.swift
//  EarthLord
//
//  Created by Claude on 2026/1/26.
//  资源显示行组件
//

import SwiftUI

/// 资源显示行组件
/// 用于显示建造/升级所需的资源及当前数量
struct ResourceRow: View {
    let resourceId: String
    let required: Int
    let available: Int

    /// 是否足够
    var isSufficient: Bool {
        available >= required
    }

    /// 资源显示名称（简单映射）
    var resourceName: String {
        let nameMap: [String: String] = [
            "wood": "木材",
            "stone": "石头",
            "metal": "金属",
            "cloth": "布料",
            "glass": "玻璃",
            "wire": "电线",
            "seed": "种子",
            "food": "食物",
            "water": "水"
        ]
        return nameMap[resourceId] ?? resourceId
    }

    /// 资源图标
    var resourceIcon: String {
        let iconMap: [String: String] = [
            "wood": "tree.fill",
            "stone": "mountain.2.fill",
            "metal": "gearshape.fill",
            "cloth": "bandage.fill",
            "glass": "rectangle.portrait.fill",
            "wire": "cable.connector",
            "seed": "leaf.fill",
            "food": "fork.knife",
            "water": "drop.fill"
        ]
        return iconMap[resourceId] ?? "cube.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            // 资源图标
            Image(systemName: resourceIcon)
                .font(.system(size: 16))
                .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
                .frame(width: 24)

            // 资源名称
            Text(resourceName)
                .font(.system(size: 14))
                .foregroundColor(.white)

            Spacer()

            // 数量显示
            HStack(spacing: 4) {
                Text("\(available)")
                    .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
                Text("/")
                    .foregroundColor(.white.opacity(0.5))
                Text("\(required)")
                    .foregroundColor(.white.opacity(0.7))
            }
            .font(.system(size: 14, weight: .medium))

            // 状态图标
            Image(systemName: isSufficient ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
}

/// 简化的资源显示（用于建筑卡片）
struct ResourceBadge: View {
    let resourceId: String
    let amount: Int

    /// 资源显示名称
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
                .font(.system(size: 10))
            Text("x\(amount)")
                .font(.system(size: 10, weight: .bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.1))
        )
        .foregroundColor(.white.opacity(0.8))
    }
}

#Preview {
    VStack(spacing: 12) {
        ResourceRow(resourceId: "wood", required: 10, available: 15)
        ResourceRow(resourceId: "stone", required: 5, available: 3)
        ResourceRow(resourceId: "metal", required: 8, available: 8)

        HStack {
            ResourceBadge(resourceId: "wood", amount: 10)
            ResourceBadge(resourceId: "stone", amount: 5)
        }
    }
    .padding()
    .background(ApocalypseTheme.background)
}
