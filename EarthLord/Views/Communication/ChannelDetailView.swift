//
//  ChannelDetailView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  频道详情视图
//

import SwiftUI

struct ChannelDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    let channel: CommunicationChannel

    @State private var isProcessing = false
    @State private var showDeleteConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var currentUserId: UUID? {
        guard let userIdStr = authManager.currentUser?.id else { return nil }
        return UUID(uuidString: userIdStr)
    }

    private var isCreator: Bool {
        currentUserId == channel.creatorId
    }

    private var isSubscribed: Bool {
        communicationManager.isSubscribed(channelId: channel.id)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 频道图标和名称
                    headerSection

                    // 频道信息
                    infoSection

                    // 描述
                    if let description = channel.description, !description.isEmpty {
                        descriptionSection(description)
                    }

                    // 操作按钮
                    actionSection

                    Spacer()
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("频道详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("删除频道", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    deleteChannel()
                }
            } message: {
                Text("确定要删除「\(channel.name)」吗？此操作不可撤销，所有订阅者将失去访问权限。")
            }
            .alert("操作失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: channel.channelType.iconName)
                    .font(.system(size: 36))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            Text(channel.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(channel.channelCode)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(8)

            if isSubscribed {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.success)
                    Text("已订阅")
                        .foregroundColor(ApocalypseTheme.success)
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                infoItem(icon: "person.2.fill", title: "成员", value: "\(channel.memberCount)")
                infoItem(icon: "antenna.radiowaves.left.and.right", title: "类型", value: channel.channelType.displayName)
                infoItem(icon: "location.fill", title: "范围", value: channel.channelType.rangeText)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func infoItem(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(ApocalypseTheme.primary)

            Text(title)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Description Section

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("频道描述")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(description)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Action Section

    private var actionSection: some View {
        VStack(spacing: 12) {
            if !isCreator {
                // 非创建者：订阅/取消订阅按钮
                if isSubscribed {
                    Button(action: unsubscribe) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.warning))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "bell.slash.fill")
                            }
                            Text(isProcessing ? "处理中..." : "取消订阅")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ApocalypseTheme.warning.opacity(0.2))
                        .foregroundColor(ApocalypseTheme.warning)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ApocalypseTheme.warning, lineWidth: 1)
                        )
                    }
                    .disabled(isProcessing)
                } else {
                    Button(action: subscribe) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "bell.fill")
                            }
                            Text(isProcessing ? "处理中..." : "订阅频道")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ApocalypseTheme.primary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessing)
                }
            } else {
                // 创建者：删除按钮
                Button(action: { showDeleteConfirmation = true }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("删除频道")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.danger.opacity(0.2))
                    .foregroundColor(ApocalypseTheme.danger)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ApocalypseTheme.danger, lineWidth: 1)
                    )
                }
                .disabled(isProcessing)

                Text("作为频道创建者，您可以删除此频道")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }

    // MARK: - Actions

    private func subscribe() {
        guard let userId = currentUserId else {
            errorMessage = "请先登录"
            showError = true
            return
        }

        isProcessing = true

        Task {
            do {
                try await communicationManager.subscribeToChannel(userId: userId, channelId: channel.id)
                await MainActor.run {
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isProcessing = false
                }
            }
        }
    }

    private func unsubscribe() {
        guard let userId = currentUserId else {
            errorMessage = "请先登录"
            showError = true
            return
        }

        isProcessing = true

        Task {
            do {
                try await communicationManager.unsubscribeFromChannel(userId: userId, channelId: channel.id)
                await MainActor.run {
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isProcessing = false
                }
            }
        }
    }

    private func deleteChannel() {
        isProcessing = true

        Task {
            do {
                try await communicationManager.deleteChannel(channelId: channel.id)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isProcessing = false
                }
            }
        }
    }
}

#Preview {
    let sampleChannel = CommunicationChannel(
        id: UUID(),
        creatorId: UUID(),
        channelType: .publicChannel,
        channelCode: "PUB-ABC123",
        name: "测试频道",
        description: "这是一个测试频道的描述",
        isActive: true,
        memberCount: 42,
        createdAt: Date(),
        updatedAt: Date()
    )

    return ChannelDetailView(channel: sampleChannel)
        .environmentObject(AuthManager(supabase: SupabaseService.shared))
}
