//
//  OfficialChannelDetailView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  官方频道详情页
//

import SwiftUI

struct OfficialChannelDetailView: View {
    @StateObject private var communicationManager = CommunicationManager.shared
    @State private var selectedCategory: MessageCategory?
    @State private var isLoading = false

    private let officialChannelId = CommunicationManager.officialChannelId

    var body: some View {
        VStack(spacing: 0) {
            // 分类过滤器
            categoryFilterBar

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 消息列表
            if isLoading {
                Spacer()
                ProgressView()
                    .tint(ApocalypseTheme.primary)
                Spacer()
            } else if filteredMessages.isEmpty {
                emptyStateView
            } else {
                messageList
            }
        }
        .background(ApocalypseTheme.background)
        .navigationTitle("官方频道")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadMessages()
        }
    }

    // MARK: - 分类过滤器

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 全部
                CategoryChip(
                    title: "全部",
                    iconName: "tray.fill",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                // 各分类
                ForEach([MessageCategory.survival, .news, .mission, .alert], id: \.self) { category in
                    CategoryChip(
                        title: category.displayName,
                        iconName: category.iconName,
                        color: category.color,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 消息列表

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredMessages) { message in
                    OfficialMessageBubble(message: message)
                }
            }
            .padding(16)
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "megaphone")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(selectedCategory == nil ? "暂无官方消息" : "暂无\(selectedCategory!.displayName)")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("官方公告将在此显示")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textMuted)
            Spacer()
        }
    }

    // MARK: - 过滤后的消息

    private var filteredMessages: [ChannelMessage] {
        let messages = communicationManager.getMessages(for: officialChannelId)

        if let category = selectedCategory {
            return messages.filter { $0.category == category }
        }
        return messages
    }

    // MARK: - 加载消息

    private func loadMessages() {
        isLoading = true
        Task {
            await communicationManager.loadChannelMessages(channelId: officialChannelId)
            communicationManager.subscribeToChannelMessages(channelId: officialChannelId)
            isLoading = false
        }
    }
}

// MARK: - 分类标签组件

private struct CategoryChip: View {
    let title: String
    let iconName: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 12))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : color.opacity(0.15))
            .cornerRadius(16)
        }
    }
}

// MARK: - 官方消息气泡

private struct OfficialMessageBubble: View {
    let message: ChannelMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 顶部：分类标签 + 时间
            HStack {
                if let category = message.category {
                    HStack(spacing: 4) {
                        Image(systemName: category.iconName)
                            .font(.system(size: 10))
                        Text(category.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(category.color.opacity(0.15))
                    .cornerRadius(8)
                }

                Spacer()

                Text(message.timeAgo)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 消息内容
            Text(message.content)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    message.category?.color.opacity(0.3) ?? ApocalypseTheme.textSecondary.opacity(0.2),
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    NavigationStack {
        OfficialChannelDetailView()
    }
}
