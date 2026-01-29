//
//  CreateTradeOfferView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  发布交易挂单页面
//

import SwiftUI

/// 发布交易挂单视图
struct CreateTradeOfferView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tradeManager = TradeManager.shared

    @State private var offeringItems: [TradeItem] = []
    @State private var requestingItems: [TradeItem] = []
    @State private var message: String = ""
    @State private var selectedExpirationHours: Int = 24
    @State private var showOfferPicker = false
    @State private var showRequestPicker = false
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    /// 有效期选项
    private let expirationOptions = [
        (hours: 6, label: "6小时"),
        (hours: 12, label: "12小时"),
        (hours: 24, label: "24小时"),
        (hours: 48, label: "2天"),
        (hours: 72, label: "3天")
    ]

    /// 是否可以提交
    private var canSubmit: Bool {
        !offeringItems.isEmpty && !requestingItems.isEmpty && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 提示信息
                    tipCard

                    // 我要出的物品
                    itemSection(
                        title: "我要出的物品",
                        subtitle: "从您的背包中选择",
                        items: offeringItems,
                        emptyText: "点击添加要交换出去的物品",
                        color: ApocalypseTheme.warning
                    ) {
                        showOfferPicker = true
                    }

                    // 交换图标
                    exchangeIndicator

                    // 我想要的物品
                    itemSection(
                        title: "我想要的物品",
                        subtitle: "选择您期望获得的物品",
                        items: requestingItems,
                        emptyText: "点击添加想要获得的物品",
                        color: ApocalypseTheme.success
                    ) {
                        showRequestPicker = true
                    }

                    // 有效期选择
                    expirationPicker

                    // 附加消息
                    messageInput

                    // 发布按钮
                    submitButton
                }
                .padding(16)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("发布挂单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .sheet(isPresented: $showOfferPicker) {
                ItemPickerView(
                    title: "选择要出的物品",
                    sourceType: .inventory,
                    selectedItems: $offeringItems
                )
            }
            .sheet(isPresented: $showRequestPicker) {
                ItemPickerView(
                    title: "选择想要的物品",
                    sourceType: .allItems,
                    selectedItems: $requestingItems
                )
            }
            .alert("发布失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("发布成功", isPresented: $showSuccess) {
                Button("好的") {
                    dismiss()
                }
            } message: {
                Text("您的挂单已成功发布，物品已从背包锁定")
            }
        }
    }

    // MARK: - 提示卡片

    private var tipCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 20))
                .foregroundColor(ApocalypseTheme.warning)

            VStack(alignment: .leading, spacing: 4) {
                Text("交易提示")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Text("发布挂单后，您出的物品将从背包锁定。挂单取消后物品会自动退还。")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.warning.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.warning.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 物品区块

    private func itemSection(
        title: String,
        subtitle: String,
        items: [TradeItem],
        emptyText: String,
        color: Color,
        onAdd: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Button(action: onAdd) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text(items.isEmpty ? "添加" : "修改")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(color.opacity(0.15))
                    )
                }
            }

            // 物品列表或空状态
            if items.isEmpty {
                Button(action: onAdd) {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle.dashed")
                                .font(.system(size: 32))
                                .foregroundColor(color.opacity(0.5))

                            Text(emptyText)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        TradeItemRow(itemId: item.itemId, quantity: item.quantity)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(items.isEmpty ? 0.2 : 0.4), lineWidth: 1)
        )
    }

    // MARK: - 交换指示器

    private var exchangeIndicator: some View {
        HStack {
            Spacer()
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.primary)
            }
            Spacer()
        }
    }

    // MARK: - 有效期选择

    private var expirationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("挂单有效期")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(expirationOptions, id: \.hours) { option in
                        let isSelected = selectedExpirationHours == option.hours

                        Button {
                            selectedExpirationHours = option.hours
                        } label: {
                            Text(option.label)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? ApocalypseTheme.primary : Color.white.opacity(0.05))
                                )
                        }
                    }
                }
            }
        }
    }

    // MARK: - 附加消息

    private var messageInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("附加消息（可选）")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            TextField("输入交易说明或备注...", text: $message, axis: .vertical)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .lineLimit(3...5)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                )

            Text("\(message.count)/100")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .onChange(of: message) { _, newValue in
            if newValue.count > 100 {
                message = String(newValue.prefix(100))
            }
        }
    }

    // MARK: - 发布按钮

    private var submitButton: some View {
        Button {
            Task {
                await submitOffer()
            }
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("发布挂单")
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canSubmit ? ApocalypseTheme.primary : ApocalypseTheme.primary.opacity(0.3))
            )
        }
        .disabled(!canSubmit)
    }

    // MARK: - 提交逻辑

    private func submitOffer() async {
        isSubmitting = true

        do {
            try await tradeManager.createOffer(
                offeringItems: offeringItems,
                requestingItems: requestingItems,
                message: message.isEmpty ? nil : message,
                expirationHours: selectedExpirationHours
            )
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isSubmitting = false
    }
}

// MARK: - 预览

#Preview {
    CreateTradeOfferView()
}
