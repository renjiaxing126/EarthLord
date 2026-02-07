//
//  ChannelChatView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  频道聊天界面（Day 34 实现）
//

import SwiftUI
import CoreLocation

struct ChannelChatView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    let channel: CommunicationChannel

    @State private var inputText = ""

    private var currentUserId: String? {
        authManager.currentUser?.id
    }

    private var canSend: Bool {
        communicationManager.canSendMessage()
    }

    private var messages: [ChannelMessage] {
        communicationManager.getMessages(for: channel.id)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 消息列表
                ScrollView(showsIndicators: false) {
                    ScrollViewReader { proxy in
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubbleView(
                                    message: message,
                                    isCurrentUser: message.senderId?.uuidString == currentUserId
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .onChange(of: messages.count) { _ in
                            if let lastId = messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                        .onAppear {
                            if let lastId = messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(ApocalypseTheme.background)

                Divider()
                    .background(ApocalypseTheme.cardBackground)

                // 底部输入区
                if canSend {
                    inputBar
                } else {
                    radioModeBar
                }
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(channel.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { }) { }  // placeholder to keep back button
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    VStack(spacing: 2) {
                        Text(channel.channelCode)
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textMuted)
                        HStack(spacing: 3) {
                            Image(systemName: "person.2")
                                .font(.caption2)
                            Text("\(channel.memberCount)")
                                .font(.caption2)
                        }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .task {
            await communicationManager.loadChannelMessages(channelId: channel.id)
            communicationManager.subscribeToChannelMessages(channelId: channel.id)
        }
        .onDisappear {
            communicationManager.unsubscribeFromChannelMessages(channelId: channel.id)
        }
    }

    // MARK: - 输入栏

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("发送消息...", text: $inputText)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(20)
                .submitLabel(.send)
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: communicationManager.isSendingMessage ? "clock" : "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                     ? ApocalypseTheme.textMuted
                                     : ApocalypseTheme.primary)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || communicationManager.isSendingMessage)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(ApocalypseTheme.background)
    }

    // MARK: - 收音机模式提示栏

    private var radioModeBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "radio")
                .font(.body)
                .foregroundColor(ApocalypseTheme.primary)
            Text("收音机模式：只能收听，无法发送消息")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal)
        .background(ApocalypseTheme.primary.opacity(0.1))
    }

    // MARK: - 发送消息

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let deviceType = communicationManager.getCurrentDeviceType().rawValue
        let location = LocationManager.shared.userLocation
        inputText = ""

        Task {
            _ = await communicationManager.sendChannelMessage(
                channelId: channel.id,
                content: trimmed,
                latitude: location?.coordinate.latitude,
                longitude: location?.coordinate.longitude,
                deviceType: deviceType
            )
        }
    }
}

// MARK: - 消息气泡

private struct MessageBubbleView: View {
    let message: ChannelMessage
    let isCurrentUser: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isCurrentUser { Spacer() }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // 发送者名称（仅非当前用户显示）
                if !isCurrentUser, let name = message.senderCallsign {
                    Text(name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }

                // 消息内容气泡
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isCurrentUser ? .white : ApocalypseTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isCurrentUser ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                    .cornerRadius(18, corners: isCurrentUser
                                  ? [.topLeft, .topRight, .bottomLeft]
                                  : [.topLeft, .topRight, .bottomRight])

                // 时间 + 设备图标
                HStack(spacing: 4) {
                    Text(message.timeAgo)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textMuted)

                    if let deviceType = message.deviceType {
                        Image(systemName: deviceIconName(for: deviceType))
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isCurrentUser ? .trailing : .leading)

            if !isCurrentUser { Spacer() }
        }
    }

    /// 设备类型 → SF Symbol 映射
    private func deviceIconName(for type: String) -> String {
        switch type {
        case "radio": return "radio"
        case "walkie_talkie": return "walkie.talkie.radio"
        case "camp_radio": return "antenna.radiowaves.left.and.right"
        case "satellite": return "antenna.radiowaves.left.and.right.circle"
        default: return "questionmark.circle"
        }
    }
}

// MARK: - 选择性角半径 Extension

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: [RectCorner]) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private enum RectCorner: CaseIterable {
    case topLeft, topRight, bottomRight, bottomLeft
}

private struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: [RectCorner] = [.topLeft, .topRight, .bottomRight, .bottomLeft]

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height

        let topRightRadius = corners.contains(.topRight) ? min(radius, width / 2, height / 2) : 0
        let topLeftRadius = corners.contains(.topLeft) ? min(radius, width / 2, height / 2) : 0
        let bottomLeftRadius = corners.contains(.bottomLeft) ? min(radius, width / 2, height / 2) : 0
        let bottomRightRadius = corners.contains(.bottomRight) ? min(radius, width / 2, height / 2) : 0

        path.move(to: CGPoint(x: rect.origin.x + topLeftRadius, y: rect.origin.y))

        // top
        path.addLine(to: CGPoint(x: rect.origin.x + width - topRightRadius, y: rect.origin.y))

        // top right
        path.addArc(center: CGPoint(x: rect.origin.x + width - topRightRadius, y: rect.origin.y + topRightRadius),
                    radius: topRightRadius,
                    startAngle: Angle(degrees: -90),
                    endAngle: Angle(degrees: 0),
                    clockwise: false)

        // right
        path.addLine(to: CGPoint(x: rect.origin.x + width, y: rect.origin.y + height - bottomRightRadius))

        // bottom right
        path.addArc(center: CGPoint(x: rect.origin.x + width - bottomRightRadius, y: rect.origin.y + height - bottomRightRadius),
                    radius: bottomRightRadius,
                    startAngle: Angle(degrees: 0),
                    endAngle: Angle(degrees: 90),
                    clockwise: false)

        // bottom
        path.addLine(to: CGPoint(x: rect.origin.x + bottomLeftRadius, y: rect.origin.y + height))

        // bottom left
        path.addArc(center: CGPoint(x: rect.origin.x + bottomLeftRadius, y: rect.origin.y + height - bottomLeftRadius),
                    radius: bottomLeftRadius,
                    startAngle: Angle(degrees: 90),
                    endAngle: Angle(degrees: 180),
                    clockwise: false)

        // left
        path.addLine(to: CGPoint(x: rect.origin.x, y: rect.origin.y + topLeftRadius))

        // top left
        path.addArc(center: CGPoint(x: rect.origin.x + topLeftRadius, y: rect.origin.y + topLeftRadius),
                    radius: topLeftRadius,
                    startAngle: Angle(degrees: 180),
                    endAngle: Angle(degrees: 270),
                    clockwise: false)

        return path
    }
}

#Preview {
    // Preview 不直接创建 CommunicationChannel，因其需要自定义解码器
    Text("ChannelChatView Preview")
}
