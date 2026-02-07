//
//  PTTCallView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  PTT 呼叫页面 - 按住说话风格的快速通讯
//

import SwiftUI
import CoreLocation

struct PTTCallView: View {
    @StateObject private var communicationManager = CommunicationManager.shared
    @EnvironmentObject var authManager: AuthManager

    @State private var selectedChannel: CommunicationChannel?
    @State private var messageText = ""
    @State private var isPTTPressed = false
    @State private var isSending = false
    @State private var showChannelPicker = false
    @State private var sendSuccess: Bool?

    // 可发送消息的频道（排除官方频道）
    private var sendableChannels: [CommunicationChannel] {
        communicationManager.subscribedChannels
            .map { $0.channel }
            .filter { !communicationManager.isOfficialChannel($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部：频道选择
            channelSelector

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 中间：消息输入区
            messageInputArea

            Spacer()

            // 底部：PTT 按钮
            pttButton

            // 状态提示
            statusBar
        }
        .background(ApocalypseTheme.background)
        .sheet(isPresented: $showChannelPicker) {
            channelPickerSheet
        }
        .onAppear {
            loadChannels()
        }
        .onChange(of: sendSuccess) { _, newValue in
            if newValue != nil {
                // 3秒后清除状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    sendSuccess = nil
                }
            }
        }
    }

    // MARK: - 频道选择器

    private var channelSelector: some View {
        Button(action: { showChannelPicker = true }) {
            HStack {
                if let channel = selectedChannel {
                    Image(systemName: channel.channelType.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text(channel.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("选择频道")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(16)
            .background(ApocalypseTheme.cardBackground)
        }
    }

    // MARK: - 消息输入区

    private var messageInputArea: some View {
        VStack(spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text("消息内容")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Spacer()
                Text("\(messageText.count)/200")
                    .font(.caption)
                    .foregroundColor(messageText.count > 200 ? ApocalypseTheme.danger : ApocalypseTheme.textMuted)
            }

            // 输入框
            TextEditor(text: $messageText)
                .scrollContentBackground(.hidden)
                .background(ApocalypseTheme.background)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .font(.body)
                .frame(height: 120)
                .padding(12)
                .background(ApocalypseTheme.background)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ApocalypseTheme.textSecondary.opacity(0.3), lineWidth: 1)
                )

            // 快捷短语
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickPhrases, id: \.self) { phrase in
                        Button(action: {
                            messageText = phrase
                        }) {
                            Text(phrase)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(ApocalypseTheme.textSecondary.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
    }

    private let quickPhrases = [
        "收到，明白",
        "需要支援",
        "发现资源",
        "注意危险",
        "正在前往",
        "到达目的地"
    ]

    // MARK: - PTT 按钮

    private var pttButton: some View {
        VStack(spacing: 12) {
            // 设备信息
            if let device = communicationManager.currentDevice {
                HStack(spacing: 6) {
                    Image(systemName: device.deviceType.iconName)
                        .font(.system(size: 12))
                    Text(device.deviceType.displayName)
                        .font(.caption)
                    Text("·")
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text(device.deviceType.rangeText)
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // PTT 按钮
            Button(action: {}) {
                ZStack {
                    // 外圈动画
                    Circle()
                        .stroke(
                            isPTTPressed ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3),
                            lineWidth: 4
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(isPTTPressed ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isPTTPressed)

                    // 内圈
                    Circle()
                        .fill(
                            isPTTPressed
                                ? ApocalypseTheme.primary
                                : (canSend ? ApocalypseTheme.primary.opacity(0.8) : ApocalypseTheme.textSecondary.opacity(0.5))
                        )
                        .frame(width: 120, height: 120)

                    // 图标和文字
                    VStack(spacing: 4) {
                        Image(systemName: isPTTPressed ? "waveform" : "mic.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)

                        Text(isPTTPressed ? "松开发送" : "按住说话")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .disabled(!canSend)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if canSend && !isPTTPressed {
                            isPTTPressed = true
                            providePTTFeedback()
                        }
                    }
                    .onEnded { _ in
                        if isPTTPressed {
                            isPTTPressed = false
                            sendMessage()
                        }
                    }
            )
        }
        .padding(.bottom, 24)
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        HStack {
            if isSending {
                ProgressView()
                    .tint(ApocalypseTheme.primary)
                    .scaleEffect(0.8)
                Text("发送中...")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            } else if let success = sendSuccess {
                Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(success ? ApocalypseTheme.success : ApocalypseTheme.danger)
                Text(success ? "发送成功" : "发送失败")
                    .font(.caption)
                    .foregroundColor(success ? ApocalypseTheme.success : ApocalypseTheme.danger)
            } else if !canSend {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(ApocalypseTheme.warning)
                Text(cannotSendReason)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.warning)
            }
        }
        .frame(height: 30)
        .padding(.bottom, 16)
    }

    // MARK: - 频道选择 Sheet

    private var channelPickerSheet: some View {
        NavigationStack {
            List(sendableChannels) { channel in
                Button(action: {
                    selectedChannel = channel
                    showChannelPicker = false
                }) {
                    HStack {
                        Image(systemName: channel.channelType.iconName)
                            .font(.system(size: 20))
                            .foregroundColor(ApocalypseTheme.primary)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(channel.name)
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text(channel.channelType.rangeText)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }

                        Spacer()

                        if selectedChannel?.id == channel.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(ApocalypseTheme.primary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
            .navigationTitle("选择频道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showChannelPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - 辅助方法

    private var canSend: Bool {
        guard let _ = selectedChannel else { return false }
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard messageText.count <= 200 else { return false }
        guard communicationManager.canSendMessage() else { return false }
        return true
    }

    private var cannotSendReason: String {
        if selectedChannel == nil {
            return "请先选择频道"
        }
        if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "请输入消息内容"
        }
        if messageText.count > 200 {
            return "消息过长"
        }
        if !communicationManager.canSendMessage() {
            return "当前设备不支持发送"
        }
        return ""
    }

    private func loadChannels() {
        guard let userIdStr = authManager.currentUser?.id,
              let userId = UUID(uuidString: userIdStr) else { return }

        Task {
            await communicationManager.loadSubscribedChannels(userId: userId)
            // 默认选择第一个可发送的频道
            if selectedChannel == nil {
                selectedChannel = sendableChannels.first
            }
        }
    }

    private func sendMessage() {
        guard let channel = selectedChannel else { return }
        guard canSend else { return }

        isSending = true
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let deviceType = communicationManager.getCurrentDeviceType().rawValue

        Task {
            let success = await communicationManager.sendChannelMessage(
                channelId: channel.id,
                content: content,
                deviceType: deviceType
            )

            isSending = false
            sendSuccess = success

            if success {
                messageText = ""
                provideSendSuccessFeedback()
            }
        }
    }

    private func providePTTFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func provideSendSuccessFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

#Preview {
    PTTCallView()
}
