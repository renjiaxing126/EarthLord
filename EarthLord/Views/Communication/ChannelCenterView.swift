//
//  ChannelCenterView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  频道中心 - 管理和发现频道
//

import SwiftUI

struct ChannelCenterView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var selectedChannel: CommunicationChannel?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            headerView

            // Tab 切换
            tabPickerView

            // 内容区域
            TabView(selection: $selectedTab) {
                myChannelsView
                    .tag(0)

                discoverChannelsView
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(ApocalypseTheme.background)
        .sheet(isPresented: $showCreateSheet) {
            CreateChannelSheet()
                .environmentObject(authManager)
        }
        .sheet(item: $selectedChannel) { channel in
            ChannelDetailView(channel: channel)
                .environmentObject(authManager)
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Text("频道中心")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            Button(action: { showCreateSheet = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - Tab Picker

    private var tabPickerView: some View {
        HStack(spacing: 0) {
            tabButton(title: "我的频道", index: 0)
            tabButton(title: "发现频道", index: 1)
        }
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button(action: { withAnimation { selectedTab = index } }) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(selectedTab == index ? .semibold : .regular)
                    .foregroundColor(selectedTab == index ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)

                Rectangle()
                    .fill(selectedTab == index ? ApocalypseTheme.primary : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // MARK: - My Channels View

    private var myChannelsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if communicationManager.subscribedChannels.isEmpty {
                    emptyStateView(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "暂无订阅频道",
                        subtitle: "去「发现频道」探索并订阅感兴趣的频道"
                    )
                } else {
                    ForEach(communicationManager.subscribedChannels) { subscribedChannel in
                        channelCard(channel: subscribedChannel.channel, isSubscribed: true)
                            .onTapGesture {
                                selectedChannel = subscribedChannel.channel
                            }
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await loadData()
        }
    }

    // MARK: - Discover Channels View

    private var discoverChannelsView: some View {
        VStack(spacing: 0) {
            // 搜索栏
            searchBar

            ScrollView {
                LazyVStack(spacing: 12) {
                    if filteredChannels.isEmpty {
                        emptyStateView(
                            icon: "magnifyingglass",
                            title: searchText.isEmpty ? "暂无频道" : "未找到匹配频道",
                            subtitle: searchText.isEmpty ? "成为第一个创建频道的人吧" : "尝试其他搜索词"
                        )
                    } else {
                        ForEach(filteredChannels) { channel in
                            channelCard(
                                channel: channel,
                                isSubscribed: communicationManager.isSubscribed(channelId: channel.id)
                            )
                            .onTapGesture {
                                selectedChannel = channel
                            }
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                await loadData()
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textSecondary)

            TextField("搜索频道...", text: $searchText)
                .foregroundColor(ApocalypseTheme.textPrimary)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .padding(10)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Channel Card

    private func channelCard(channel: CommunicationChannel, isSubscribed: Bool) -> some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: channel.channelType.iconName)
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(channel.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    if isSubscribed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.success)
                    }
                }

                Text(channel.channelCode)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                HStack(spacing: 8) {
                    Label("\(channel.memberCount)", systemImage: "person.2")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(channel.channelType.displayName)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(4)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Empty State

    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 60)

            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(title)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var filteredChannels: [CommunicationChannel] {
        if searchText.isEmpty {
            return communicationManager.channels
        }
        return communicationManager.channels.filter { channel in
            channel.name.localizedCaseInsensitiveContains(searchText) ||
            channel.channelCode.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func loadData() async {
        await communicationManager.loadPublicChannels()
        if let userIdStr = authManager.currentUser?.id,
           let userId = UUID(uuidString: userIdStr) {
            await communicationManager.loadSubscribedChannels(userId: userId)
        }
    }
}

#Preview {
    ChannelCenterView()
        .environmentObject(AuthManager(supabase: SupabaseService.shared))
}
