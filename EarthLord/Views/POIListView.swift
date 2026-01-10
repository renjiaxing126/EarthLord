//
//  POIListView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/9.
//  显示附近兴趣点的列表页面
//

import SwiftUI

struct POIListView: View {
    // MARK: - State

    /// 当前选中的筛选类型（nil 表示全部）
    @State private var selectedFilter: POIType? = nil

    /// 是否正在搜索
    @State private var isSearching = false

    /// 搜索按钮是否被按下
    @State private var isSearchButtonPressed = false

    /// 列表是否已加载
    @State private var hasAppeared = false

    /// 假的 GPS 坐标
    private let fakeGPSCoordinate = (latitude: 22.54, longitude: 114.06)

    /// 从 Mock 数据加载 POI
    private var allPOIs: [POI] {
        MockExplorationData.mockPOIs
    }

    /// 根据筛选条件过滤后的 POI
    private var filteredPOIs: [POI] {
        if let filter = selectedFilter {
            return allPOIs.filter { $0.type == filter }
        }
        return allPOIs
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 状态栏
                statusBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                // 搜索按钮
                searchButton
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                // 筛选工具栏
                filterToolbar
                    .padding(.vertical, 12)

                // POI 列表或空状态
                if filteredPOIs.isEmpty {
                    emptyStateView
                } else {
                    poiList
                }
            }
        }
        .navigationTitle("附近地点")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 子视图

    /// 状态栏
    private var statusBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // GPS 坐标
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("GPS: \(String(format: "%.2f", fakeGPSCoordinate.latitude)), \(String(format: "%.2f", fakeGPSCoordinate.longitude))")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 发现数量
                Text("附近发现 \(allPOIs.count) 个地点")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 搜索按钮
    private var searchButton: some View {
        Button(action: {
            performSearch()
        }) {
            HStack(spacing: 12) {
                if isSearching {
                    // 加载动画
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)

                    Text("搜索中...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("搜索附近POI")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.primary)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isSearching)
        .opacity(isSearching ? 0.7 : 1.0)
    }

    /// 筛选工具栏
    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 全部按钮
                filterButton(title: "全部", type: nil)

                // 各类型按钮
                ForEach(POIType.allCases, id: \.self) { type in
                    filterButton(title: type.rawValue, type: type)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// 筛选按钮
    private func filterButton(title: String, type: POIType?) -> some View {
        let isSelected = selectedFilter == type

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = type
            }
        }) {
            HStack(spacing: 6) {
                // 图标（如果有类型）
                if let type = type {
                    Image(systemName: type.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .white : type.color)
                }

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : ApocalypseTheme.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isSelected ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
    }

    /// POI 列表
    private var poiList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(filteredPOIs.enumerated()), id: \.element.id) { index, poi in
                    NavigationLink(destination: POIDetailView(poi: poi)) {
                        poiCard(poi: poi)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(
                        .easeOut(duration: 0.4).delay(Double(index) * 0.1),
                        value: hasAppeared
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .onAppear {
            hasAppeared = true
        }
    }

    /// POI 卡片
    private func poiCard(poi: POI) -> some View {
        HStack(spacing: 12) {
            // 类型图标
            ZStack {
                Circle()
                    .fill(poi.type.color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: poi.type.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(poi.type.color)
            }

            // 信息区域
            VStack(alignment: .leading, spacing: 6) {
                // 名称和类型
                HStack {
                    Text(poi.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    // 类型标签
                    Text(poi.type.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(poi.type.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(poi.type.color.opacity(0.15))
                        )
                }

                // 距离
                if let distance = poi.distanceFromUser {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11))
                        Text(String(format: "%.0f米", distance))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 状态和物资
                HStack(spacing: 12) {
                    // 发现状态
                    statusBadge(poi: poi)

                    // 物资状态
                    resourceBadge(poi: poi)
                }
            }

            Spacer()

            // 箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(poi.type.color.opacity(0.3), lineWidth: 1)
        )
    }

    /// 状态徽章
    private func statusBadge(poi: POI) -> some View {
        let (text, color): (String, Color) = {
            switch poi.status {
            case .undiscovered:
                return ("未发现", ApocalypseTheme.textMuted)
            case .discovered:
                return ("已发现", ApocalypseTheme.info)
            case .depleted:
                return ("已搜空", ApocalypseTheme.danger)
            }
        }()

        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
        }
    }

    /// 物资徽章
    private func resourceBadge(poi: POI) -> some View {
        HStack(spacing: 4) {
            Image(systemName: poi.hasResources ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(poi.hasResources ? ApocalypseTheme.success : ApocalypseTheme.danger)

            Text(poi.hasResources ? "有物资" : "无物资")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(poi.hasResources ? ApocalypseTheme.success : ApocalypseTheme.danger)
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.textMuted.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: selectedFilter == nil ? "map" : "magnifyingglass")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 文字
            VStack(spacing: 8) {
                Text(selectedFilter == nil ? "附近暂无兴趣点" : "没有找到该类型的地点")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                if selectedFilter == nil {
                    Text("点击搜索按钮发现周围的废墟")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .multilineTextAlignment(.center)
                } else {
                    Button(action: {
                        withAnimation {
                            selectedFilter = nil
                        }
                    }) {
                        Text("清除筛选")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 方法

    /// 执行搜索（模拟网络请求）
    private func performSearch() {
        isSearching = true

        // 1.5秒后恢复
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isSearching = false
            }
        }
    }
}

// MARK: - 按钮样式

/// 带缩放效果的按钮样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - 预览

#Preview {
    NavigationView {
        POIListView()
    }
}
