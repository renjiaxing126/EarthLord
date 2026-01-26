//
//  TerritoryDetailView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/8.
//  重构：Day 29 全屏地图布局
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {
    let territory: Territory
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var buildingManager = BuildingManager.shared

    // MARK: - 状态

    /// 显示信息面板
    @State private var showInfoPanel = true

    /// 显示建筑浏览器
    @State private var showBuildingBrowser = false

    /// 选中的建筑模板（用于建造）
    @State private var selectedTemplateForConstruction: BuildingTemplate?

    /// 显示删除确认
    @State private var showDeleteAlert = false

    /// 显示重命名
    @State private var showRenameAlert = false

    /// 新名称
    @State private var newTerritoryName = ""

    /// 正在删除
    @State private var isDeleting = false

    /// 删除错误
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""

    /// 显示升级确认
    @State private var buildingToUpgrade: PlayerBuilding?

    /// 显示拆除确认
    @State private var buildingToDemolish: PlayerBuilding?

    /// 操作错误
    @State private var showOperationError = false
    @State private var operationErrorMessage = ""

    private let territoryManager = TerritoryManager.shared

    // MARK: - 计算属性

    /// 领地坐标（GCJ-02）
    private var territoryCoordinates: [CLLocationCoordinate2D] {
        territory.toCoordinates().map { coord in
            CoordinateConverter.wgs84ToGcj02(coord)
        }
    }

    /// 该领地的建筑列表
    private var territoryBuildings: [PlayerBuilding] {
        buildingManager.playerBuildings.filter { $0.territoryId == territory.id }
    }

    /// 地图相机位置
    private var mapCameraPosition: MapCameraPosition {
        guard let firstCoord = territoryCoordinates.first else {
            return .automatic
        }

        // 计算领地中心
        let lats = territoryCoordinates.map { $0.latitude }
        let lons = territoryCoordinates.map { $0.longitude }
        let centerLat = (lats.min()! + lats.max()!) / 2
        let centerLon = (lons.min()! + lons.max()!) / 2

        return .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        ))
    }

    var body: some View {
        ZStack {
            // 1. 全屏地图（底层）
            mapLayer
                .ignoresSafeArea()

            // 2. 悬浮工具栏（顶部）
            VStack {
                toolbarView
                Spacer()
            }

            // 3. 可折叠信息面板（底部）
            VStack {
                Spacer()
                if showInfoPanel {
                    infoPanelView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .task {
            // 加载该领地的建筑
            await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
        }
        // Sheet: 建筑浏览器
        .sheet(isPresented: $showBuildingBrowser) {
            BuildingBrowserView { template in
                showBuildingBrowser = false
                // 延迟避免动画冲突
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    selectedTemplateForConstruction = template
                }
            }
        }
        // Sheet: 建造确认页
        .sheet(item: $selectedTemplateForConstruction) { template in
            BuildingPlacementView(
                template: template,
                territory: territory
            ) {
                // 建造完成回调
                Task {
                    await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
                }
            }
        }
        // Alert: 删除确认
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task { await deleteTerritory() }
            }
        } message: {
            Text("确定要删除这个领地吗？领地内的所有建筑也将被删除。此操作无法撤销。")
        }
        // Alert: 删除错误
        .alert("删除失败", isPresented: $showDeleteError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage)
        }
        // Alert: 重命名
        .alert("重命名领地", isPresented: $showRenameAlert) {
            TextField("领地名称", text: $newTerritoryName)
            Button("取消", role: .cancel) {}
            Button("确定") {
                Task { await renameTerritory() }
            }
        } message: {
            Text("请输入新的领地名称")
        }
        // Alert: 升级确认
        .alert("升级建筑", isPresented: .init(
            get: { buildingToUpgrade != nil },
            set: { if !$0 { buildingToUpgrade = nil } }
        )) {
            Button("取消", role: .cancel) {}
            Button("升级") {
                if let building = buildingToUpgrade {
                    Task { await upgradeBuilding(building) }
                }
            }
        } message: {
            if let building = buildingToUpgrade {
                Text("确定要升级 \(building.buildingName) 吗？")
            }
        }
        // Alert: 拆除确认
        .alert("拆除建筑", isPresented: .init(
            get: { buildingToDemolish != nil },
            set: { if !$0 { buildingToDemolish = nil } }
        )) {
            Button("取消", role: .cancel) {}
            Button("拆除", role: .destructive) {
                if let building = buildingToDemolish {
                    Task { await demolishBuilding(building) }
                }
            }
        } message: {
            if let building = buildingToDemolish {
                Text("确定要拆除 \(building.buildingName) 吗？此操作无法撤销且不会返还资源。")
            }
        }
        // Alert: 操作错误
        .alert("操作失败", isPresented: $showOperationError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(operationErrorMessage)
        }
    }

    // MARK: - 地图层

    private var mapLayer: some View {
        Map(position: .constant(mapCameraPosition)) {
            // 绘制领地多边形
            MapPolygon(coordinates: territoryCoordinates)
                .foregroundStyle(.green.opacity(0.25))
                .stroke(.green, lineWidth: 2)

            // 绘制建筑标注
            ForEach(territoryBuildings) { building in
                if let coord = building.coordinate {
                    // 转换为 GCJ-02
                    let gcj02Coord = CoordinateConverter.wgs84ToGcj02(coord)
                    Annotation(building.buildingName, coordinate: gcj02Coord) {
                        buildingAnnotationView(for: building)
                    }
                }
            }
        }
        .mapStyle(.hybrid)
    }

    /// 建筑标注视图
    private func buildingAnnotationView(for building: PlayerBuilding) -> some View {
        let template = buildingManager.getTemplate(by: building.templateId)

        return ZStack {
            Circle()
                .fill(building.status == .constructing ? Color.blue : Color.green)
                .frame(width: 32, height: 32)

            Image(systemName: template?.icon ?? "building.2.fill")
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
    }

    // MARK: - 悬浮工具栏

    private var toolbarView: some View {
        HStack(spacing: 12) {
            // 关闭按钮
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }

            Spacer()

            // 领地名称
            Text(territory.displayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.5)))

            Spacer()

            // 建造按钮
            Button {
                showBuildingBrowser = true
            } label: {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(ApocalypseTheme.primary))
            }

            // 更多菜单
            Menu {
                Button {
                    newTerritoryName = territory.name ?? ""
                    showRenameAlert = true
                } label: {
                    Label("重命名", systemImage: "pencil")
                }

                Button {
                    withAnimation(.spring()) {
                        showInfoPanel.toggle()
                    }
                } label: {
                    Label(showInfoPanel ? "隐藏面板" : "显示面板", systemImage: showInfoPanel ? "chevron.down" : "chevron.up")
                }

                Divider()

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("删除领地", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - 信息面板

    private var infoPanelView: some View {
        VStack(spacing: 16) {
            // 拖动指示器
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)

            // 领地信息
            territoryInfoSection

            // 建筑列表
            if !territoryBuildings.isEmpty {
                buildingListSection
            }

            // 空状态
            if territoryBuildings.isEmpty {
                emptyBuildingState
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(white: 0.1))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - 领地信息部分

    private var territoryInfoSection: some View {
        HStack(spacing: 16) {
            // 面积
            VStack(spacing: 4) {
                Image(systemName: "map.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.primary)
                Text(territory.formattedArea)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text("面积")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.2))

            // 建筑数量
            VStack(spacing: 4) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                Text("\(territoryBuildings.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text("建筑")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.2))

            // 点数
            VStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                Text("\(territory.pointCount ?? 0)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text("边界点")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - 建筑列表部分

    private var buildingListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("建筑列表")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(territoryBuildings.count) 个建筑")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            // 建筑行列表（限制高度可滚动）
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(territoryBuildings) { building in
                        TerritoryBuildingRow(
                            building: building,
                            template: buildingManager.getTemplate(by: building.templateId),
                            onUpgrade: {
                                buildingToUpgrade = building
                            },
                            onDemolish: {
                                buildingToDemolish = building
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }

    // MARK: - 空建筑状态

    private var emptyBuildingState: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))

            Text("暂无建筑")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))

            Button {
                showBuildingBrowser = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("开始建造")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - 方法

    private func deleteTerritory() async {
        isDeleting = true
        do {
            try await territoryManager.deleteTerritory(territoryId: territory.id)
            dismiss()
            onDelete?()
            NotificationCenter.default.post(name: .territoryUpdated, object: nil)
        } catch {
            deleteErrorMessage = error.localizedDescription
            showDeleteError = true
        }
        isDeleting = false
    }

    private func renameTerritory() async {
        guard !newTerritoryName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        do {
            try await territoryManager.updateTerritoryName(
                territoryId: territory.id,
                name: newTerritoryName
            )
            NotificationCenter.default.post(name: .territoryUpdated, object: nil)
        } catch {
            operationErrorMessage = "重命名失败: \(error.localizedDescription)"
            showOperationError = true
        }
    }

    private func upgradeBuilding(_ building: PlayerBuilding) async {
        do {
            try await buildingManager.upgradeBuilding(buildingId: building.id)
            await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
        } catch {
            operationErrorMessage = error.localizedDescription
            showOperationError = true
        }
        buildingToUpgrade = nil
    }

    private func demolishBuilding(_ building: PlayerBuilding) async {
        do {
            try await buildingManager.demolishBuilding(buildingId: building.id)
            await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
        } catch {
            operationErrorMessage = error.localizedDescription
            showOperationError = true
        }
        buildingToDemolish = nil
    }
}

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "123",
            userId: "456",
            name: "测试领地",
            path: [["lat": 31.2, "lon": 121.4], ["lat": 31.21, "lon": 121.4], ["lat": 31.21, "lon": 121.41], ["lat": 31.2, "lon": 121.41]],
            area: 10000,
            pointCount: 4,
            isActive: true,
            completedAt: nil,
            startedAt: nil,
            createdAt: "2026-01-08T10:00:00Z"
        ),
        onDelete: nil
    )
}
