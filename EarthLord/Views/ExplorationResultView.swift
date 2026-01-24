//
//  ExplorationResultView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/10.
//  探索结果页面 - 显示探索收获的弹窗
//

import SwiftUI

struct ExplorationResultView: View {
    // MARK: - Properties

    let stats: ExplorationStats?
    let reward: ExplorationReward?
    let rewardTier: RewardTier?
    let error: String?

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    /// 动画状态
    @State private var showContent = false
    @State private var showStats = false
    @State private var showRewards = false
    @State private var showButton = false

    /// 数字动画状态
    @State private var animatedWalkDistance: Double = 0
    @State private var animatedWalkDistanceTotal: Double = 0

    /// 奖励物品动画状态
    @State private var visibleRewardsCount = 0

    /// 是否处于错误状态
    private var isError: Bool {
        error != nil
    }

    // MARK: - 初始化

    /// 成功状态初始化
    init(stats: ExplorationStats, reward: ExplorationReward, tier: RewardTier = .bronze) {
        self.stats = stats
        self.reward = reward
        self.rewardTier = tier
        self.error = nil
    }

    /// 错误状态初始化
    init(error: String) {
        self.stats = nil
        self.reward = nil
        self.rewardTier = nil
        self.error = error
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            if isError {
                // 错误状态
                errorStateView
            } else {
                // 成功状态
                ScrollView {
                    VStack(spacing: 24) {
                        // 顶部间距
                        Spacer()
                            .frame(height: 20)

                        // 成就标题
                        if showContent {
                            achievementHeader
                                .transition(.scale.combined(with: .opacity))
                        }

                        // 统计数据卡片
                        if showStats {
                            statsCard
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }

                        // 奖励物品卡片
                        if showRewards {
                            rewardsCard
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }

                        // 确认按钮
                        if showButton {
                            confirmButton
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        // 底部间距
                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            if !isError {
                playAnimationSequence()
            } else {
                // 错误状态的入场动画
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                    showContent = true
                }
            }
        }
    }

    // MARK: - 子视图

    /// 成就标题区域
    private var achievementHeader: some View {
        VStack(spacing: 20) {
            // 大图标（带装饰效果）
            ZStack {
                // 外圈光晕 - 根据等级使用不同颜色
                let tierColor = rewardTier?.color ?? ApocalypseTheme.success
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                tierColor.opacity(0.3),
                                tierColor.opacity(0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                // 中间圆形背景
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                tierColor,
                                tierColor.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: tierColor.opacity(0.5), radius: 20, x: 0, y: 10)

                // 等级图标
                Image(systemName: rewardTier?.icon ?? "map.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)

                // 对勾角标
                Circle()
                    .fill(ApocalypseTheme.primary)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: 35, y: -35)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 8, x: 0, y: 4)
            }
            .padding(.top, 20)

            // 大文字和等级徽章
            VStack(spacing: 12) {
                Text("探索完成！")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 等级徽章
                if let tier = rewardTier {
                    HStack(spacing: 8) {
                        Image(systemName: tier.icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(tier.color)

                        Text(tier.rawValue)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(tier.color)

                        Text("奖励")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(tier.color.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(tier.color.opacity(0.3), lineWidth: 1)
                            )
                    )
                }

                Text("成功探索新区域")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }

    /// 统计数据卡片
    private var statsCard: some View {
        VStack(spacing: 0) {
            // 卡片标题
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("探索统计")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            if let stats = stats {
                VStack(spacing: 0) {
                    // 行走距离
                    statRow(
                        icon: "figure.walk",
                        title: "行走距离",
                        current: formatDistance(animatedWalkDistance),
                        total: formatDistance(animatedWalkDistanceTotal),
                        rank: stats.distanceRank
                    )

                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.3))
                        .padding(.horizontal, 16)

                    // 探索时长
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(ApocalypseTheme.info)

                            Text("探索时长")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }

                        Spacer()

                        Text(formatDuration(stats.explorationTime))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 统计数据行
    private func statRow(icon: String, title: String, current: String, total: String, rank: Int) -> some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.warning)

                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()
            }

            // 数据显示
            HStack(spacing: 20) {
                // 本次
                VStack(alignment: .leading, spacing: 4) {
                    Text("本次")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(current)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // 累计
                VStack(alignment: .leading, spacing: 4) {
                    Text("累计")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(total)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                Spacer()

                // 排名
                VStack(spacing: 4) {
                    Text("排名")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text("#\(rank)")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.success)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(ApocalypseTheme.success.opacity(0.15))
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    /// 奖励物品卡片
    private var rewardsCard: some View {
        VStack(spacing: 0) {
            if let reward = reward {
                // 卡片标题
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("获得物品")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    // 物品数量标签
                    Text("\(reward.items.count) 种")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(ApocalypseTheme.primary.opacity(0.15))
                        )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 物品列表
                VStack(spacing: 0) {
                    ForEach(Array(reward.items.enumerated()), id: \.offset) { index, item in
                        if index < visibleRewardsCount {
                            rewardItemRow(item: item, index: index)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .opacity
                                ))

                            if index < reward.items.count - 1 {
                                Divider()
                                    .background(ApocalypseTheme.textMuted.opacity(0.2))
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 底部提示
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.success)

                    Text("已添加到背包")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.success)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.success.opacity(0.1))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 奖励物品行
    private func rewardItemRow(item: RewardItem, index: Int) -> some View {
        HStack(spacing: 12) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: item.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 物品信息
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("数量: \(item.quantity)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 对勾图标（带弹跳效果）
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(ApocalypseTheme.success)
                .scaleEffect(index < visibleRewardsCount ? 1.0 : 0.5)
                .animation(
                    .spring(response: 0.3, dampingFraction: 0.5).delay(Double(index) * 0.2 + 0.9),
                    value: visibleRewardsCount
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// 确认按钮
    private var confirmButton: some View {
        Button(action: {
            dismiss()
        }) {
            HStack(spacing: 12) {
                Text("太棒了！")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(
                color: ApocalypseTheme.primary.opacity(0.4),
                radius: 12,
                x: 0,
                y: 6
            )
        }
    }

    /// 错误状态视图
    private var errorStateView: some View {
        VStack(spacing: 32) {
            Spacer()

            if showContent {
                VStack(spacing: 24) {
                    // 错误图标
                    ZStack {
                        Circle()
                            .fill(ApocalypseTheme.danger.opacity(0.2))
                            .frame(width: 140, height: 140)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(ApocalypseTheme.danger)
                    }
                    .transition(.scale.combined(with: .opacity))

                    // 错误标题和信息
                    VStack(spacing: 12) {
                        Text("探索失败")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text(error ?? "探索过程中发生了未知错误")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .lineSpacing(4)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))

                    // 按钮组
                    VStack(spacing: 12) {
                        // 重试按钮
                        Button(action: {
                            // TODO: 重试探索逻辑
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)

                                Text("重试探索")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                ApocalypseTheme.primary,
                                                ApocalypseTheme.primaryDark
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(
                                color: ApocalypseTheme.primary.opacity(0.4),
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                        }

                        // 取消按钮
                        Button(action: {
                            dismiss()
                        }) {
                            Text("取消")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(ApocalypseTheme.cardBackground)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 辅助方法

    /// 播放动画序列
    private func playAnimationSequence() {
        guard let stats = stats, let reward = reward else { return }

        // 1. 标题出现
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            showContent = true
        }

        // 2. 统计数据出现
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
            showStats = true
        }

        // 2.5 数字动画（从0跳到目标值）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedWalkDistance = stats.walkDistance
                animatedWalkDistanceTotal = stats.totalWalkDistance
            }
        }

        // 3. 奖励物品依次出现
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.7)) {
            showRewards = true
        }

        // 3.5 奖励物品逐个显示
        for i in 0..<reward.items.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8 + Double(i) * 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    visibleRewardsCount = i + 1
                }
            }
        }

        // 4. 按钮出现
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(1.0 + Double(reward.items.count) * 0.2)) {
            showButton = true
        }
    }

    /// 格式化距离
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1fkm", meters / 1000)
        } else {
            return String(format: "%.0fm", meters)
        }
    }

    /// 格式化时长
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d分%d秒", minutes, secs)
    }
}

// MARK: - 预览

#Preview {
    ExplorationResultView(
        stats: MockExplorationData.mockExplorationResult.stats,
        reward: MockExplorationData.mockExplorationResult.reward,
        tier: .gold
    )
}

#Preview("作为弹窗") {
    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            ExplorationResultView(
                stats: MockExplorationData.mockExplorationResult.stats,
                reward: MockExplorationData.mockExplorationResult.reward,
                tier: .diamond
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
}

#Preview("错误状态") {
    ExplorationResultView(error: "探索区域存在未知危险，请稍后重试")
}

#Preview("错误状态弹窗") {
    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            ExplorationResultView(error: "GPS信号丢失，无法完成探索")
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
}
