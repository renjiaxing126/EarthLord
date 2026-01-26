//
//  BuildingBrowserView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/26.
//  建筑浏览器视图
//

import SwiftUI

/// 建筑浏览器视图
/// 显示所有可建造的建筑模板，支持分类筛选
struct BuildingBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var buildingManager = BuildingManager.shared

    /// 当前选中的分类（nil表示全部）
    @State private var selectedCategory: BuildingCategory?

    /// 选中的建筑模板（用于显示详情）
    @State private var selectedTemplate: BuildingTemplate?

    /// 建造开始回调
    let onStartConstruction: (BuildingTemplate) -> Void

    /// 过滤后的模板列表
    var filteredTemplates: [BuildingTemplate] {
        if let category = selectedCategory {
            return buildingManager.buildingTemplates.filter { $0.category == category }
        }
        return buildingManager.buildingTemplates
    }

    /// 网格列定义
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 分类选择栏
                categoryBar

                // 建筑网格
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredTemplates) { template in
                            BuildingCard(template: template) {
                                selectedTemplate = template
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle("建筑浏览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .sheet(item: $selectedTemplate) { template in
                BuildingDetailView(
                    template: template,
                    onStartConstruction: { selectedTemplate in
                        // 关闭详情页
                        self.selectedTemplate = nil
                        // 延迟后调用回调
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onStartConstruction(selectedTemplate)
                        }
                    }
                )
            }
        }
    }

    // MARK: - 分类选择栏

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 全部按钮
                AllCategoryButton(isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                // 各分类按钮
                ForEach(BuildingCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color.black.opacity(0.3))
    }
}

#Preview {
    BuildingBrowserView { template in
        print("Selected: \(template.name)")
    }
}
