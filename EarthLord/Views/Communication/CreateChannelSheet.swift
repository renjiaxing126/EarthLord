//
//  CreateChannelSheet.swift
//  EarthLord
//
//  Created by Claude on 2026/1/28.
//  创建频道表单
//

import SwiftUI

struct CreateChannelSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: ChannelType = .publicChannel
    @State private var channelName = ""
    @State private var channelDescription = ""
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 频道类型选择
                    typeSelectionSection

                    // 频道名称
                    nameInputSection

                    // 频道描述
                    descriptionInputSection

                    // 创建按钮
                    createButton
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("创建频道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("创建失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Type Selection

    private var typeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("频道类型")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(ChannelType.creatableTypes, id: \.self) { type in
                    typeCard(type: type)
                }
            }
        }
    }

    private func typeCard(type: ChannelType) -> some View {
        let isSelected = selectedType == type

        return Button(action: { selectedType = type }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? ApocalypseTheme.primary.opacity(0.2) : ApocalypseTheme.cardBackground)
                        .frame(width: 48, height: 48)

                    Image(systemName: type.iconName)
                        .font(.title2)
                        .foregroundColor(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                }

                Text(type.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? ApocalypseTheme.textPrimary : ApocalypseTheme.textSecondary)

                Text(type.rangeText)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? ApocalypseTheme.primary : Color.clear, lineWidth: 2)
            )
        }
    }

    // MARK: - Name Input

    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("频道名称")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(channelName.count)/50")
                    .font(.caption)
                    .foregroundColor(isNameValid ? ApocalypseTheme.textMuted : ApocalypseTheme.danger)
            }

            TextField("输入频道名称", text: $channelName)
                .textFieldStyle(.plain)
                .padding()
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(8)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .onChange(of: channelName) { _, newValue in
                    if newValue.count > 50 {
                        channelName = String(newValue.prefix(50))
                    }
                }

            if !isNameValid && !channelName.isEmpty {
                Text("频道名称需要 2-50 个字符")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }
        }
    }

    // MARK: - Description Input

    private var descriptionInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("频道描述")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("(可选)")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            TextEditor(text: $channelDescription)
                .frame(minHeight: 80)
                .padding(8)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(8)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .onChange(of: channelDescription) { _, newValue in
                    if newValue.count > 200 {
                        channelDescription = String(newValue.prefix(200))
                    }
                }

            Text("\(channelDescription.count)/200")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button(action: createChannel) {
            HStack {
                if isCreating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                }
                Text(isCreating ? "创建中..." : "创建频道")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canCreate ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canCreate || isCreating)
    }

    // MARK: - Helpers

    private var isNameValid: Bool {
        channelName.count >= 2 && channelName.count <= 50
    }

    private var canCreate: Bool {
        isNameValid
    }

    private func createChannel() {
        guard let userIdStr = authManager.currentUser?.id,
              let userId = UUID(uuidString: userIdStr) else {
            errorMessage = "请先登录"
            showError = true
            return
        }

        isCreating = true

        Task {
            do {
                let description = channelDescription.isEmpty ? nil : channelDescription
                _ = try await communicationManager.createChannel(
                    userId: userId,
                    type: selectedType,
                    name: channelName,
                    description: description
                )

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isCreating = false
                }
            }
        }
    }
}

#Preview {
    CreateChannelSheet()
        .environmentObject(AuthManager(supabase: SupabaseService.shared))
}
