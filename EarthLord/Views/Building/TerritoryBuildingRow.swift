//
//  TerritoryBuildingRow.swift
//  EarthLord
//
//  Created by Claude on 2026/1/26.
//  领地建筑行组件
//

import SwiftUI
import Combine

/// 领地建筑行组件
/// 显示建筑信息，支持操作菜单（升级/拆除）
struct TerritoryBuildingRow: View {
    let building: PlayerBuilding
    let template: BuildingTemplate?

    /// 升级回调
    let onUpgrade: () -> Void

    /// 拆除回调
    let onDemolish: () -> Void

    /// 当前时间（用于计算进度）
    @State private var currentTime = Date()

    /// 计时器
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            // 建筑图标
            buildingIcon

            // 建筑信息
            buildingInfo

            Spacer()

            // 右侧操作区
            rightSection
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }

    // MARK: - 建筑图标

    private var buildingIcon: some View {
        ZStack {
            // 背景
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 48, height: 48)

            // 图标或进度
            if building.status == .constructing {
                // 建造中显示进度环
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 3)

                    Circle()
                        .trim(from: 0, to: buildProgress)
                        .stroke(ApocalypseTheme.info, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    Image(systemName: template?.icon ?? "building.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.info)
                }
                .frame(width: 40, height: 40)
            } else {
                Image(systemName: template?.icon ?? "building.2.fill")
                    .font(.system(size: 20))
                    .foregroundColor(template?.category.color ?? .green)
            }
        }
    }

    // MARK: - 建筑信息

    private var buildingInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 名称和等级
            HStack(spacing: 6) {
                Text(building.buildingName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                if building.status == .active {
                    Text("Lv.\(building.level)")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.purple.opacity(0.3))
                        )
                        .foregroundColor(.purple)
                }
            }

            // 状态信息
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)

                if building.status == .constructing {
                    Text("建造中 - \(remainingTimeText)")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.info)
                } else {
                    Text(building.status.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(statusColor)
                }
            }
        }
    }

    // MARK: - 右侧操作区

    @ViewBuilder
    private var rightSection: some View {
        if building.status == .constructing {
            // 建造中显示进度百分比
            Text("\(Int(buildProgress * 100))%")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(ApocalypseTheme.info)
        } else {
            // 运行中显示操作菜单
            Menu {
                // 升级按钮
                if let template = template, building.level < template.maxLevel {
                    Button {
                        onUpgrade()
                    } label: {
                        Label("升级", systemImage: "arrow.up.circle")
                    }
                }

                // 拆除按钮
                Button(role: .destructive) {
                    onDemolish()
                } label: {
                    Label("拆除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - 计算属性

    /// 状态颜色
    private var statusColor: Color {
        switch building.status {
        case .constructing:
            return ApocalypseTheme.info
        case .active:
            return ApocalypseTheme.success
        }
    }

    /// 建造进度（0-1）
    private var buildProgress: CGFloat {
        guard building.status == .constructing,
              let template = template else {
            return 1.0
        }

        let elapsed = currentTime.timeIntervalSince(building.buildStartedAt)
        let total = Double(template.buildTimeSeconds)
        return min(1.0, CGFloat(elapsed / total))
    }

    /// 剩余时间文字
    private var remainingTimeText: String {
        guard building.status == .constructing,
              let template = template else {
            return ""
        }

        let elapsed = currentTime.timeIntervalSince(building.buildStartedAt)
        let remaining = max(0, Double(template.buildTimeSeconds) - elapsed)

        if remaining <= 0 {
            return "即将完成"
        } else if remaining < 60 {
            return "\(Int(remaining))秒"
        } else if remaining < 3600 {
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            return "\(minutes)分\(seconds)秒"
        } else {
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            return "\(hours)小时\(minutes)分"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        // 建造中
        TerritoryBuildingRow(
            building: PlayerBuilding(
                id: UUID(),
                userId: UUID(),
                territoryId: "123",
                templateId: "shelter",
                buildingName: "庇护所",
                status: .constructing,
                level: 1,
                locationLat: 31.2,
                locationLon: 121.4,
                buildStartedAt: Date().addingTimeInterval(-60),
                buildCompletedAt: nil,
                createdAt: nil,
                updatedAt: nil
            ),
            template: BuildingTemplate(
                id: UUID(),
                templateId: "shelter",
                name: "庇护所",
                tier: 1,
                category: .survival,
                description: "简易庇护所",
                icon: "house.fill",
                requiredResources: [:],
                buildTimeSeconds: 180,
                maxPerTerritory: 1,
                maxLevel: 5
            ),
            onUpgrade: {},
            onDemolish: {}
        )

        // 运行中
        TerritoryBuildingRow(
            building: PlayerBuilding(
                id: UUID(),
                userId: UUID(),
                territoryId: "123",
                templateId: "campfire",
                buildingName: "篝火",
                status: .active,
                level: 2,
                locationLat: 31.2,
                locationLon: 121.4,
                buildStartedAt: Date(),
                buildCompletedAt: Date(),
                createdAt: nil,
                updatedAt: nil
            ),
            template: BuildingTemplate(
                id: UUID(),
                templateId: "campfire",
                name: "篝火",
                tier: 1,
                category: .survival,
                description: "提供温暖",
                icon: "flame.fill",
                requiredResources: [:],
                buildTimeSeconds: 60,
                maxPerTerritory: 2,
                maxLevel: 3
            ),
            onUpgrade: {},
            onDemolish: {}
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
