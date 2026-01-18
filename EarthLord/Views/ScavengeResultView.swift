//
//  ScavengeResultView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/14.
//  POI搜刮结果展示视图
//

import SwiftUI
import CoreLocation

/// POI搜刮结果视图
struct ScavengeResultView: View {
    let poi: ExplorablePOI?
    let rewards: [GeneratedRewardItem]
    @Environment(\.dismiss) private var dismiss

    @State private var showItems = false
    @State private var itemsAppeared: [Bool] = []
    @State private var expandedStories: Set<String> = []

    var body: some View {
        VStack(spacing: 24) {
            // 顶部成功标识
            successHeader

            // POI信息
            if let poi = poi {
                poiInfoSection(poi: poi)
            }

            // 获得物品列表
            rewardsSection

            Spacer()

            // 确认按钮
            confirmButton
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.12),
                    Color(red: 0.05, green: 0.05, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            // 初始化动画状态
            itemsAppeared = Array(repeating: false, count: rewards.count)

            // 延迟显示物品列表
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showItems = true
                }

                // 逐个显示物品
                for index in rewards.indices {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(index) * 0.15) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            if index < itemsAppeared.count {
                                itemsAppeared[index] = true
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 组件

    /// 成功标识头部
    private var successHeader: some View {
        VStack(spacing: 16) {
            // 成功图标
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.green.opacity(0.3), .green.opacity(0.1)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.bounce, options: .nonRepeating)
            }

            // 标题
            Text("搜刮成功！")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        }
    }

    /// POI信息区域
    private func poiInfoSection(poi: ExplorablePOI) -> some View {
        HStack(spacing: 12) {
            // POI图标
            Image(systemName: poi.type.icon)
                .font(.system(size: 24))
                .foregroundColor(poi.type.color)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(poi.type.color.opacity(0.2))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(poi.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Text(poi.type.rawValue)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
    }

    /// 获得物品区域
    private var rewardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundColor(.yellow)
                Text("获得物品")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("已添加到背包")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            // 物品列表
            if showItems {
                VStack(spacing: 12) {
                    ForEach(Array(rewards.enumerated()), id: \.element.id) { index, reward in
                        rewardItemRow(reward: reward, index: index)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    /// 单个物品行
    private func rewardItemRow(reward: GeneratedRewardItem, index: Int) -> some View {
        let appeared = index < itemsAppeared.count ? itemsAppeared[index] : false
        let isExpanded = expandedStories.contains(reward.id)
        let hasStory = reward.isAIGenerated && reward.aiStory != nil && !reward.aiStory!.isEmpty

        return VStack(spacing: 0) {
            // 主行
            HStack(spacing: 12) {
                // 物品图标（带AI标识）
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: reward.icon)
                        .font(.system(size: 20))
                        .foregroundColor(rarityColor(reward.rarity))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(rarityColor(reward.rarity).opacity(0.2))
                        )

                    // AI生成标识
                    if reward.isAIGenerated {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.yellow)
                            .padding(3)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                            )
                            .offset(x: 4, y: 4)
                    }
                }

                // 物品信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(reward.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)

                        // 稀有度标签
                        Text(reward.rarity.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(rarityColor(reward.rarity))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(rarityColor(reward.rarity).opacity(0.2))
                            )
                    }

                    // 分类信息（AI物品显示分类，本地物品显示itemId）
                    Text(reward.isAIGenerated ? reward.category : reward.itemId)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                // 数量
                Text("x\(reward.quantity)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // 展开按钮（仅有故事时显示）
                if hasStory {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if isExpanded {
                                expandedStories.remove(reward.id)
                            } else {
                                expandedStories.insert(reward.id)
                            }
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                }
            }
            .padding(12)

            // 可展开的故事区域
            if hasStory && isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(Color.white.opacity(0.1))

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.yellow.opacity(0.8))

                        Text(reward.aiStory ?? "")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 50)
        .scaleEffect(appeared ? 1 : 0.8)
    }

    /// 确认按钮
    private var confirmButton: some View {
        Button {
            dismiss()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("确认")
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
    }

    // MARK: - 辅助方法

    /// 根据稀有度返回颜色
    private func rarityColor(_ rarity: ItemRarity) -> Color {
        return rarity.color
    }
}

#Preview {
    ScavengeResultView(
        poi: ExplorablePOI(
            name: "协和医院",
            type: .hospital,
            coordinate: .init(latitude: 0, longitude: 0)
        ),
        rewards: [
            GeneratedRewardItem(
                id: "1",
                itemId: "ai_emergency_kit_12345",
                name: "「最后的希望」应急包",
                icon: "cross.case.fill",
                rarity: .epic,
                quantity: 1,
                category: "医疗",
                isAIGenerated: true,
                aiStory: "这个急救包上贴着一张便签：'给值夜班的自己准备的'。里面的绷带和药品都保存完好，仿佛主人从未来得及使用它。"
            ),
            GeneratedRewardItem(
                id: "2",
                itemId: "canned_food",
                name: "罐头食品",
                icon: "fork.knife",
                rarity: .common,
                quantity: 2
            ),
            GeneratedRewardItem(
                id: "3",
                itemId: "ai_flashlight_67890",
                name: "医用手电筒",
                icon: "flashlight.on.fill",
                rarity: .rare,
                quantity: 1,
                category: "照明",
                isAIGenerated: true,
                aiStory: "电量还剩一半，手柄上刻着一个护士的名字。在末日中，光明比黄金还珍贵。"
            )
        ]
    )
}
