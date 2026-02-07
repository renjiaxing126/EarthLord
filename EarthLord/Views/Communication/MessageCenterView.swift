//
//  MessageCenterView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  消息中心 - 聚合所有订阅频道的消息
//

import SwiftUI

struct MessageCenterView: View {
    @StateObject private var communicationManager = CommunicationManager.shared
    @EnvironmentObject var authManager: AuthManager
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if communicationManager.subscribedChannels.isEmpty {
                    emptyStateView
                } else {
                    channelList
                }
            }
            .background(ApocalypseTheme.background)
        }
        .onAppear {
            loadData()
        }
    }

    // MARK: - 加载视图

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(ApocalypseTheme.primary)
            Spacer()
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text("暂无订阅频道")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("前往「频道」页面订阅感兴趣的频道")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(32)
    }

    // MARK: - 频道列表

    private var channelList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(communicationManager.getChannelSummaries()) { summary in
                    NavigationLink {
                        destinationView(for: summary.channel)
                    } label: {
                        MessageRowView(summary: summary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .padding(16)
        }
    }

    // MARK: - 目标视图

    @ViewBuilder
    private func destinationView(for channel: CommunicationChannel) -> some View {
        if communicationManager.isOfficialChannel(channel.id) {
            OfficialChannelDetailView()
        } else {
            ChannelChatView(channel: channel)
        }
    }

    // MARK: - 加载数据

    private func loadData() {
        guard let userIdStr = authManager.currentUser?.id,
              let userId = UUID(uuidString: userIdStr) else { return }

        isLoading = true
        Task {
            await communicationManager.loadSubscribedChannels(userId: userId)
            await communicationManager.loadAllChannelLatestMessages()
            isLoading = false
        }
    }
}

// MARK: - 消息行视图

struct MessageRowView: View {
    let summary: CommunicationManager.ChannelSummary

    private var isOfficial: Bool {
        CommunicationManager.shared.isOfficialChannel(summary.channel.id)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 频道图标
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 48, height: 48)

                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }

            // 频道信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(summary.channel.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    if isOfficial {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.primary)
                    }

                    Spacer()

                    if let message = summary.latestMessage {
                        Text(message.timeAgo)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }

                // 最新消息预览
                if let message = summary.latestMessage {
                    Text(messagePreview(message))
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("暂无消息")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .italic()
                }
            }

            // 箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 辅助属性

    private var iconName: String {
        if isOfficial {
            return "megaphone.fill"
        }
        return summary.channel.channelType.iconName
    }

    private var iconColor: Color {
        if isOfficial {
            return ApocalypseTheme.primary
        }
        return ApocalypseTheme.textPrimary
    }

    private var iconBackgroundColor: Color {
        if isOfficial {
            return ApocalypseTheme.primary.opacity(0.2)
        }
        return ApocalypseTheme.textSecondary.opacity(0.15)
    }

    private func messagePreview(_ message: ChannelMessage) -> String {
        if let callsign = message.senderCallsign, !callsign.isEmpty {
            return "[\(callsign)] \(message.content)"
        }
        return message.content
    }
}

#Preview {
    MessageCenterView()
}
