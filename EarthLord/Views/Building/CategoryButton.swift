//
//  CategoryButton.swift
//  EarthLord
//
//  Created by Claude on 2026/1/26.
//  建筑类别按钮组件
//

import SwiftUI

/// 建筑类别按钮组件
struct CategoryButton: View {
    let category: BuildingCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 20))

                Text(category.displayName)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(minWidth: 60)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? ApocalypseTheme.primary : Color.white.opacity(0.1))
            )
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
}

/// 全部类别按钮（特殊处理）
struct AllCategoryButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 20))

                Text("全部")
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(minWidth: 60)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? ApocalypseTheme.primary : Color.white.opacity(0.1))
            )
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 8) {
        AllCategoryButton(isSelected: true) {}
        CategoryButton(category: .survival, isSelected: false) {}
        CategoryButton(category: .storage, isSelected: false) {}
        CategoryButton(category: .production, isSelected: false) {}
        CategoryButton(category: .energy, isSelected: false) {}
    }
    .padding()
    .background(ApocalypseTheme.background)
}
