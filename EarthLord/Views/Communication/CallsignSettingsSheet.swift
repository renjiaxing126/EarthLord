//
//  CallsignSettingsSheet.swift
//  EarthLord
//
//  Created by Claude on 2026/2/7.
//  呼号设置页面
//

import SwiftUI

struct CallsignSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var communicationManager = CommunicationManager.shared
    @EnvironmentObject var authManager: AuthManager

    @State private var callsign = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 说明卡片
                    infoCard

                    // 输入区域
                    inputSection

                    // 示例
                    exampleSection

                    Spacer(minLength: 40)
                }
                .padding(16)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("呼号设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveCallsign()
                    }
                    .disabled(isSaving || callsign.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundColor(
                        callsign.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? ApocalypseTheme.textMuted
                            : ApocalypseTheme.primary
                    )
                }
            }
            .onAppear {
                loadCallsign()
            }
            .alert("保存成功", isPresented: $showSaveSuccess) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("你的呼号已更新为「\(callsign)」")
            }
            .alert("保存失败", isPresented: .constant(errorMessage != nil)) {
                Button("确定") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: - 说明卡片

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.wave.2.fill")
                    .font(.system(size: 24))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("什么是呼号？")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Text("呼号是你在无线电通讯中的代号，其他幸存者会通过呼号识别你。选择一个简短、易记的呼号，让队友能快速认出你。")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 输入区域

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("你的呼号")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text("\(callsign.count)/12")
                    .font(.caption)
                    .foregroundColor(callsign.count > 12 ? ApocalypseTheme.danger : ApocalypseTheme.textMuted)
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(ApocalypseTheme.primary)
                    Spacer()
                }
                .frame(height: 50)
            } else {
                TextField("输入呼号...", text: $callsign)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding(16)
                    .background(ApocalypseTheme.background)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                callsign.count > 12
                                    ? ApocalypseTheme.danger
                                    : ApocalypseTheme.textSecondary.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            }

            if callsign.count > 12 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text("呼号不能超过12个字符")
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.danger)
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 示例

    private var exampleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("呼号示例")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textSecondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(exampleCallsigns, id: \.self) { example in
                    Button(action: {
                        callsign = example
                    }) {
                        Text(example)
                            .font(.subheadline)
                            .foregroundColor(
                                callsign == example
                                    ? .white
                                    : ApocalypseTheme.textPrimary
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(
                                callsign == example
                                    ? ApocalypseTheme.primary
                                    : ApocalypseTheme.textSecondary.opacity(0.15)
                            )
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private let exampleCallsigns = [
        "猎鹰", "夜莺", "幽灵",
        "风暴", "铁拳", "黑豹",
        "雷神", "暗影", "银狐"
    ]

    // MARK: - 方法

    private func loadCallsign() {
        guard let userIdStr = authManager.currentUser?.id,
              let userId = UUID(uuidString: userIdStr) else { return }

        isLoading = true
        Task {
            if let savedCallsign = await communicationManager.loadUserCallsign(userId: userId) {
                callsign = savedCallsign
            }
            isLoading = false
        }
    }

    private func saveCallsign() {
        guard let userIdStr = authManager.currentUser?.id,
              let userId = UUID(uuidString: userIdStr) else { return }

        let trimmedCallsign = callsign.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCallsign.isEmpty else { return }
        guard trimmedCallsign.count <= 12 else {
            errorMessage = "呼号不能超过12个字符"
            return
        }

        isSaving = true
        Task {
            let success = await communicationManager.saveUserCallsign(userId: userId, callsign: trimmedCallsign)
            isSaving = false

            if success {
                showSaveSuccess = true
            } else {
                errorMessage = communicationManager.errorMessage ?? "保存失败"
            }
        }
    }
}

#Preview {
    CallsignSettingsSheet()
}
