//
//  TerritoryDetailView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/8.
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {
    let territory: Territory
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    private let territoryManager = TerritoryManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 地图预览
                    mapPreview

                    // 领地信息
                    territoryInfo

                    // 删除按钮
                    deleteButton

                    // 未来功能占位
                    futureFeaturesSection
                }
                .padding()
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle(territory.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    Task {
                        await deleteTerritory()
                    }
                }
            } message: {
                Text("确定要删除这个领地吗？此操作无法撤销。")
            }
            .alert("删除失败", isPresented: $showDeleteError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(deleteErrorMessage)
            }
        }
    }

    // MARK: - 地图预览

    private var mapPreview: some View {
        Map(position: .constant(mapCameraPosition)) {
            // 绘制领地多边形
            MapPolygon(coordinates: territoryCoordinates)
                .foregroundStyle(.green.opacity(0.3))
                .stroke(.green, lineWidth: 2)
        }
        .frame(height: 300)
        .cornerRadius(16)
        .allowsHitTesting(false)
    }

    // MARK: - 领地信息

    private var territoryInfo: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Text("领地信息")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }

            // 信息卡片
            VStack(spacing: 12) {
                InfoRow(icon: "map.fill", label: "面积", value: territory.formattedArea)
                if let pointCount = territory.pointCount {
                    InfoRow(icon: "mappin.circle.fill", label: "点数", value: "\(pointCount)")
                }
                if let createdAt = territory.createdAt {
                    InfoRow(icon: "calendar", label: "创建时间", value: formatDate(createdAt))
                }
                if let startedAt = territory.startedAt {
                    InfoRow(icon: "play.circle", label: "开始时间", value: formatDate(startedAt))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    // MARK: - 删除按钮

    private var deleteButton: some View {
        Button {
            showDeleteAlert = true
        } label: {
            HStack {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "trash.fill")
                }
                Text(isDeleting ? "删除中..." : "删除领地")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red)
            )
            .foregroundColor(.white)
        }
        .disabled(isDeleting)
    }

    // MARK: - 未来功能占位

    private var futureFeaturesSection: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Text("更多功能")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }

            // 功能占位卡片
            VStack(spacing: 12) {
                FeaturePlaceholder(icon: "pencil", title: "重命名领地")
                FeaturePlaceholder(icon: "building.2.fill", title: "建筑系统")
                FeaturePlaceholder(icon: "dollarsign.circle.fill", title: "领地交易")
            }
        }
    }

    // MARK: - 计算属性

    private var territoryCoordinates: [CLLocationCoordinate2D] {
        let coords = territory.toCoordinates()
        // 转换为 GCJ-02 坐标
        return coords.map { coord in
            CoordinateConverter.wgs84ToGcj02(coord)
        }
    }

    private var mapCameraPosition: MapCameraPosition {
        guard let firstCoord = territoryCoordinates.first else {
            return .automatic
        }
        return .region(MKCoordinateRegion(
            center: firstCoord,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    // MARK: - 方法

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return displayFormatter.string(from: date)
    }

    private func deleteTerritory() async {
        isDeleting = true
        do {
            try await territoryManager.deleteTerritory(territoryId: territory.id)
            // 删除成功，调用回调并关闭页面
            dismiss()
            onDelete?()
            // 发送通知，让地图和领地列表都刷新
            NotificationCenter.default.post(name: .territoryUpdated, object: nil)
        } catch {
            deleteErrorMessage = error.localizedDescription
            showDeleteError = true
        }
        isDeleting = false
    }
}

// MARK: - 信息行

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)

            Text(label)
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
}

// MARK: - 功能占位卡片

struct FeaturePlaceholder: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 24)

            Text(title)
                .foregroundColor(.white.opacity(0.5))

            Spacer()

            Text("敬请期待")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
    }
}

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "123",
            userId: "456",
            name: "测试领地",
            path: [["lat": 31.2, "lon": 121.4], ["lat": 31.3, "lon": 121.5]],
            area: 1000,
            pointCount: 10,
            isActive: true,
            completedAt: nil,
            startedAt: nil,
            createdAt: "2026-01-08T10:00:00Z"
        ),
        onDelete: nil
    )
}
