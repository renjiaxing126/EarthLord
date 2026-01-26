//
//  MapTabView.swift
//  EarthLord
//
//  Created by yanshuang ren on 2026/1/4.
//

import SwiftUI
import MapKit
import Supabase

struct MapTabView: View {
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var explorationManager = ExplorationManager.shared
    @StateObject private var buildingManager = BuildingManager.shared
    private let territoryManager = TerritoryManager.shared
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showSpeedWarning = false
    @State private var showValidationBanner = false
    @State private var showUploadError = false
    @State private var uploadErrorMessage = ""
    @State private var showUploadSuccess = false
    @State private var isUploading = false
    @State private var trackingStartTime: Date?
    @State private var territories: [Territory] = []
    @State private var currentUserId: String?
    @State private var showStopConfirmation = false  // 停止圈地二次确认

    // MARK: - Day 19: 碰撞检测状态
    @State private var collisionCheckTimer: Timer?
    @State private var collisionWarning: String?
    @State private var showCollisionWarning = false
    @State private var collisionWarningLevel: WarningLevel = .safe

    // MARK: - 建筑显示状态
    @State private var buildingUpdateVersion = 0

    // MARK: - 探索功能状态
    @State private var showExplorationResult = false
    @State private var explorationRewards: [GeneratedRewardItem] = []
    @State private var explorationDistance: Double = 0
    @State private var explorationDuration: TimeInterval = 0
    @State private var explorationTier: RewardTier = .none

    var body: some View {
        ZStack {
            // 地图视图
            MapViewRepresentable(
                locationManager: locationManager,
                trackingPath: $locationManager.pathCoordinates,
                pathUpdateVersion: locationManager.pathUpdateVersion,
                isTracking: locationManager.isTracking,
                isPathClosed: locationManager.isPathClosed,
                territories: territories,
                currentUserId: currentUserId,
                explorablePOIs: explorationManager.nearbyPOIs,
                poiUpdateVersion: explorationManager.poiUpdateVersion,
                onPOITapped: { poi in
                    // 点击POI时的处理（可选：手动触发搜刮弹窗）
                    if !poi.isScavenged && explorationManager.isExploring {
                        explorationManager.currentApproachingPOI = poi
                        explorationManager.showPOIPopup = true
                    }
                },
                playerBuildings: buildingManager.playerBuildings,
                buildingUpdateVersion: buildingUpdateVersion
            )
            .ignoresSafeArea()

            // 顶部状态栏、速度警告和验证结果横幅
            VStack(spacing: 12) {
                statusBar

                // 速度警告横幅
                if let warning = locationManager.speedWarning, showSpeedWarning {
                    speedWarningBanner(warning: warning)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 验证结果横幅
                if showValidationBanner {
                    validationResultBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 上传成功横幅
                if showUploadSuccess {
                    uploadSuccessBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 上传错误横幅
                if showUploadError {
                    uploadErrorBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Day 19: 碰撞警告横幅（分级颜色）
                if showCollisionWarning, let warning = collisionWarning {
                    collisionWarningBanner(message: warning, level: collisionWarningLevel)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 探索超速警告横幅
                if explorationManager.isOverSpeed {
                    explorationSpeedWarningBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 旧的探索状态横幅已移到底部

                // 探索失败横幅
                if explorationManager.state == .failed {
                    explorationFailedBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }

            // 底部区域（紧贴Tab Bar上方）
            VStack(spacing: 0) {
                Spacer()

                // 确认登记按钮（验证通过时显示在顶部）
                if locationManager.territoryValidationPassed && !explorationManager.isExploring {
                    HStack {
                        Spacer()
                        confirmButton
                            .padding(.trailing, 16)
                            .padding(.bottom, 12)
                    }
                }

                // 探索状态面板（探索进行中显示）
                if explorationManager.isExploring {
                    explorationStatusPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 8)
                } else {
                    // 底部三按钮行：开始圈地 | 定位 | 探索
                    bottomButtonBar
                        .padding(.bottom, 8)
                }
            }
            .padding(.bottom, 0) // 紧贴底部Tab Bar
            .animation(.easeInOut(duration: 0.3), value: explorationManager.isExploring)

            // 权限请求或错误提示
            if locationManager.isDenied {
                permissionDeniedView
            } else if locationManager.authorizationStatus == .notDetermined {
                permissionRequestView
            }
        }
        .onChange(of: locationManager.speedWarning) {
            if locationManager.speedWarning != nil {
                // 显示警告
                withAnimation {
                    showSpeedWarning = true
                }
                // 3秒后自动隐藏
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        showSpeedWarning = false
                    }
                }
            }
        }
        // 监听闭环状态，闭环后根据验证结果显示横幅
        .onReceive(locationManager.$isPathClosed) { isClosed in
            if isClosed {
                // 闭环后延迟一点点，等待验证结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        showValidationBanner = true
                    }
                    // 3 秒后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showValidationBanner = false
                        }
                    }
                }
            }
        }
        .onAppear {
            print("🗺️ MapTabView 出现")
            checkLocationPermission()
            Task {
                await loadTerritories()
            }
        }
        .onDisappear {
            print("🗺️ MapTabView 消失")
            // 清理碰撞检测定时器，防止内存泄漏
            stopCollisionCheckTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .territoryUpdated)) { _ in
            // 收到领地更新通知（删除后），刷新地图上的领地
            Task {
                await loadTerritories()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .triggerCollisionCheck)) { _ in
            // Day 19: 收到碰撞检测触发通知（定时器触发）
            performCollisionCheck()
        }
        .onReceive(NotificationCenter.default.publisher(for: .buildingUpdated)) { _ in
            // 收到建筑更新通知，刷新地图上的建筑
            buildingUpdateVersion += 1
            Task {
                await buildingManager.fetchAllPlayerBuildings()
            }
        }
        .task {
            // 加载所有玩家建筑
            await buildingManager.fetchAllPlayerBuildings()
        }
        .sheet(isPresented: $showExplorationResult) {
            // 使用真实探索数据
            if explorationTier == .none {
                // 距离不足，显示错误状态
                ExplorationResultView(error: "探索距离不足200米，无法获得奖励。请继续行走探索！")
            } else {
                // 有奖励，显示成功状态
                let stats = ExplorationStats(
                    walkDistance: explorationDistance,
                    explorationTime: explorationDuration,
                    totalWalkDistance: explorationDistance, // TODO: 累计数据需要从数据库获取
                    distanceRank: 99 // TODO: 排名需要从数据库获取
                )
                let reward = ExplorationReward(
                    items: RewardGenerator.shared.convertToLegacyRewards(explorationRewards)
                )
                ExplorationResultView(stats: stats, reward: reward, tier: explorationTier)
            }
        }
        // POI接近弹窗
        .sheet(isPresented: $explorationManager.showPOIPopup) {
            if let poi = explorationManager.currentApproachingPOI {
                POIProximitySheet(
                    poi: poi,
                    userLocation: locationManager.userLocation,
                    onScavenge: {
                        _ = await explorationManager.scavengePOI(poi)
                    },
                    onDismiss: {
                        explorationManager.dismissPOIPopup()
                    }
                )
            }
        }
        // POI搜刮结果弹窗
        .sheet(isPresented: $explorationManager.showScavengeResult) {
            ScavengeResultView(
                poi: explorationManager.currentApproachingPOI,
                rewards: explorationManager.lastScavengeRewards
            )
        }
        .onChange(of: explorationManager.showScavengeResult) {
            // 搜刮结果弹窗关闭时清理状态
            if !explorationManager.showScavengeResult {
                explorationManager.dismissScavengeResult()
            }
        }
        .onChange(of: showExplorationResult) {
            // 当结果页面关闭时，完成结算
            if !showExplorationResult {
                Task {
                    // 只有有奖励时才保存到背包
                    if explorationTier != .none {
                        await InventoryManager.shared.addItems(explorationRewards, source: "exploration")
                    }
                    // 无论有没有奖励都要重置状态！
                    explorationManager.finishSettlement()
                    print("✅ [MapTabView] 结算完成，状态已重置")
                }
            }
        }
    }

    // MARK: - 组件

    /// 顶部状态栏
    private var statusBar: some View {
        HStack {
            // 左侧：定位状态
            HStack(spacing: 8) {
                if locationManager.isAuthorized {
                    Image(systemName: "location.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                    if let location = locationManager.userLocation {
                        Text(String(format: "%.6f, %.6f",
                                  location.coordinate.latitude,
                                  location.coordinate.longitude))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    } else {
                        LocalizedText(key: "定位中...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    Image(systemName: "location.slash.fill")
                        .foregroundColor(.red)
                    LocalizedText(key: "定位未授权")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.8))
            )

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 60) // 避开安全区域
    }

    /// 权限未授权提示视图
    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            // 图标
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "location.slash.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
            }

            // 文字说明
            VStack(spacing: 12) {
                LocalizedText(key: "定位权限被拒绝")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                LocalizedText(key: "请在设置中开启定位权限以使用地图功能")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // 打开设置按钮
            Button {
                openSettings()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                    LocalizedText(key: "打开设置")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ApocalypseTheme.primary)
                )
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.09, green: 0.09, blue: 0.09))
        )
        .padding(24)
    }

    /// 权限请求视图
    private var permissionRequestView: some View {
        VStack(spacing: 24) {
            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "location.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 文字说明
            VStack(spacing: 12) {
                LocalizedText(key: "需要访问您的位置")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                LocalizedText(key: "为了在地图上显示您的位置，需要获取定位权限")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // 授权按钮
            Button {
                locationManager.requestPermission()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                    LocalizedText(key: "授权定位")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ApocalypseTheme.primary)
                )
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.09, green: 0.09, blue: 0.09))
        )
        .padding(24)
    }

    /// 速度警告横幅
    private func speedWarningBanner(warning: String) -> some View {
        HStack(spacing: 12) {
            // 警告图标
            Image(systemName: locationManager.isTracking ? "exclamationmark.triangle.fill" : "exclamationmark.octagon.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            // 警告文字
            Text(warning)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(locationManager.isTracking ? Color.orange : Color.red)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.body)
            if locationManager.territoryValidationPassed {
                Text("圈地成功！领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "验证失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(locationManager.territoryValidationPassed ? Color.green : Color.red)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }

    /// 上传成功横幅
    private var uploadSuccessBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
            Text("领地登记成功！")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }

    /// 上传错误横幅
    private var uploadErrorBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .font(.body)
            Text(uploadErrorMessage)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .onTapGesture {
            showUploadError = false
        }
    }

    /// 圈地按钮
    private var claimButton: some View {
        Button {
            if locationManager.isTracking {
                // ⚠️ 停止追踪需要二次确认，防止误触
                showStopConfirmation = true
            } else {
                // Day 19: 开始圈地前检测起始点
                startClaimingWithCollisionCheck()
            }
        } label: {
            HStack(spacing: 8) {
                // 图标
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.system(size: 16, weight: .semibold))

                // 文字
                if locationManager.isTracking {
                    Text("停止圈地")
                    Text("(\(locationManager.pathCoordinates.count))")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                } else {
                    Text("开始圈地")
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(locationManager.isTracking ? Color.red : ApocalypseTheme.primary)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
        }
        .disabled(!locationManager.isAuthorized)
        .opacity(locationManager.isAuthorized ? 1.0 : 0.5)
        .alert("确认停止圈地", isPresented: $showStopConfirmation) {
            Button("继续圈地", role: .cancel) {
                // 取消，继续圈地
            }
            Button("确认停止", role: .destructive) {
                // 确认停止追踪
                stopCollisionMonitoring()  // Day 19: 完全停止，清除警告
                locationManager.stopPathTracking()
                trackingStartTime = nil
            }
        } message: {
            Text("已记录 \(locationManager.pathCoordinates.count) 个点，确定要停止吗？停止后当前路径将被清空。")
        }
    }

    /// 确认登记按钮
    private var confirmButton: some View {
        Button {
            Task {
                await uploadCurrentTerritory()
            }
        } label: {
            HStack(spacing: 8) {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(isUploading ? "上传中..." : "确认登记领地")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.green)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
        }
        .disabled(isUploading)
    }

    /// 底部按钮栏（三个按钮水平排列）
    private var bottomButtonBar: some View {
        HStack(spacing: 12) {
            // 左侧：开始圈地按钮
            claimButton
                .frame(maxWidth: .infinity)

            // 中间：定位按钮
            locationButton
                .frame(width: 60)

            // 右侧：探索按钮
            exploreButton
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
    }

    /// 定位按钮
    private var locationButton: some View {
        Button {
            // 定位到当前位置
            if let location = locationManager.userLocation {
                // 这里可以添加地图定位逻辑，暂时只触发震动反馈
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 60, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ApocalypseTheme.primary)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
        .disabled(!locationManager.isAuthorized)
        .opacity(locationManager.isAuthorized ? 1.0 : 0.5)
    }

    /// 探索按钮
    private var exploreButton: some View {
        Button {
            toggleExploration()
        } label: {
            HStack(spacing: 8) {
                if explorationManager.isExploring {
                    // 探索中状态 - 显示结束探索
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16, weight: .semibold))

                    Text("结束探索")
                        .font(.system(size: 16, weight: .semibold))
                } else {
                    // 空闲状态 - 显示开始探索
                    Image(systemName: "binoculars.fill")
                        .font(.system(size: 16, weight: .semibold))

                    Text("探索")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(explorationManager.isExploring ? Color.red : ApocalypseTheme.primary)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
        }
        .disabled(!locationManager.isAuthorized)
        .opacity(locationManager.isAuthorized ? 1.0 : 0.6)
    }

    // MARK: - 方法

    /// 检查定位权限
    private func checkLocationPermission() {
        if locationManager.authorizationStatus == .notDetermined {
            print("⚠️ 定位权限未确定")
        } else if locationManager.isAuthorized {
            print("✅ 定位权限已授权，开始更新位置")
            locationManager.startUpdatingLocation()
        } else if locationManager.isDenied {
            print("❌ 定位权限被拒绝")
        }
    }

    /// 打开系统设置
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
            print("📱 打开系统设置")
        }
    }

    /// 加载所有领地
    private func loadTerritories() async {
        do {
            // 获取当前用户 ID
            if let userId = try? await SupabaseService.shared.auth.session.user.id {
                currentUserId = userId.uuidString
            }

            // 加载所有领地并缓存（用于碰撞检测）
            try await territoryManager.loadAndCacheTerritories()
            territories = territoryManager.territories
            TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
        } catch {
            TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
        }
    }

    /// 上传当前领地
    private func uploadCurrentTerritory() async {
        // ⚠️ 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            uploadErrorMessage = "领地验证未通过，无法上传"
            showUploadError = true
            return
        }

        // 检查是否有路径数据
        guard !locationManager.pathCoordinates.isEmpty else {
            uploadErrorMessage = "没有路径数据"
            showUploadError = true
            return
        }

        // 开始上传
        isUploading = true

        do {
            try await territoryManager.uploadTerritory(
                coordinates: locationManager.pathCoordinates,
                area: locationManager.calculatedArea,
                startTime: trackingStartTime ?? Date()
            )

            // 上传成功
            showUploadSuccess = true

            // ⚠️ 关键：上传成功后必须停止追踪！
            // 这会重置所有状态，防止重复上传
            stopCollisionMonitoring()  // Day 19: 完全停止，清除警告
            locationManager.stopPathTracking()

            // 发送通知，让所有监听者刷新领地（包括本视图）
            // 注意：不在这里直接调用 loadTerritories()，避免重复加载
            NotificationCenter.default.post(name: .territoryUpdated, object: nil)

            // 3秒后隐藏成功消息
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                showUploadSuccess = false
            }

        } catch {
            // 上传失败 - 将错误信息转换为中文
            uploadErrorMessage = localizeError(error.localizedDescription)
            showUploadError = true
        }

        isUploading = false
    }

    // MARK: - Day 19: 碰撞检测方法

    /// Day 19: 带碰撞检测的开始圈地
    private func startClaimingWithCollisionCheck() {
        print("🚩 开始圈地检查：location=\(locationManager.userLocation != nil), userId=\(currentUserId ?? "nil")")

        // ⚠️ 关键修复：如果 currentUserId 为空，立即尝试获取
        if currentUserId == nil {
            print("⚠️ currentUserId 为空，立即尝试获取...")
            Task {
                do {
                    let session = try await SupabaseService.shared.auth.session
                    await MainActor.run {
                        currentUserId = session.user.id.uuidString
                        print("✅ 成功获取 userId: \(session.user.id.uuidString)")
                        TerritoryLogger.shared.log("获取用户ID: \(session.user.id.uuidString)", type: .info)
                        // 获取到ID后，立即执行检测
                        performStartWithCollisionCheck()
                    }
                } catch {
                    print("❌ 获取用户ID失败: \(error)")
                    TerritoryLogger.shared.log("获取用户ID失败: \(error.localizedDescription)", type: .error)
                    // 失败了也要继续，但碰撞检测会失效
                    await MainActor.run {
                        performStartWithoutCollisionCheck()
                    }
                }
            }
            return
        }

        // 有 userId，继续检测
        performStartWithCollisionCheck()
    }

    /// 执行带碰撞检测的开始逻辑
    private func performStartWithCollisionCheck() {
        guard let location = locationManager.userLocation else {
            print("❌ 无法获取当前位置")
            performStartWithoutCollisionCheck()
            return
        }

        guard let userId = currentUserId else {
            print("❌ userId 仍然为空")
            performStartWithoutCollisionCheck()
            return
        }

        print("✅ 开始起点碰撞检测")

        // 检测起始点是否在他人领地内
        let result = territoryManager.checkPointCollision(
            point: location.coordinate,
            excludeUserId: userId
        )

        if result.hasCollision {
            // 起点在他人领地内，显示错误并震动
            collisionWarning = result.message
            collisionWarningLevel = .violation
            withAnimation {
                showCollisionWarning = true
            }

            // 错误震动
            triggerHapticFeedback(level: .violation)

            TerritoryLogger.shared.log("起点碰撞：阻止圈地", type: .error)

            // 3秒后隐藏警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showCollisionWarning = false
                }
                collisionWarning = nil
                collisionWarningLevel = .safe
            }

            return
        }

        // 起点安全，开始圈地
        TerritoryLogger.shared.log("起始点安全，开始圈地", type: .info)
        trackingStartTime = Date()
        locationManager.startPathTracking()
        startCollisionMonitoring()
    }

    /// 执行不带碰撞检测的开始逻辑（降级方案）
    private func performStartWithoutCollisionCheck() {
        print("⚠️ 跳过碰撞检测，直接开始圈地")
        TerritoryLogger.shared.log("警告：用户ID未获取，碰撞检测已禁用", type: .warning)
        trackingStartTime = Date()
        locationManager.startPathTracking()
        // 不启动碰撞监控
    }

    /// Day 19: 启动碰撞检测监控
    private func startCollisionMonitoring() {
        // 先停止已有定时器
        stopCollisionCheckTimer()

        // 立即执行一次检测
        performCollisionCheck()

        // 每 10 秒检测一次
        // 注意：由于 MapTabView 是 struct，不能在 Timer 闭包中直接调用实例方法
        // 因此需要通过通知机制来触发检测
        collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .triggerCollisionCheck, object: nil)
            }
        }

        TerritoryLogger.shared.log("碰撞检测定时器已启动（每10秒）", type: .info)
    }

    /// Day 19: 仅停止定时器（不清除警告状态）
    private func stopCollisionCheckTimer() {
        collisionCheckTimer?.invalidate()
        collisionCheckTimer = nil
    }

    /// Day 19: 完全停止碰撞监控（停止定时器 + 清除警告）
    private func stopCollisionMonitoring() {
        stopCollisionCheckTimer()
        // 清除警告状态
        showCollisionWarning = false
        collisionWarning = nil
        collisionWarningLevel = .safe
    }

    /// Day 19: 执行碰撞检测
    private func performCollisionCheck() {
        // ⚠️ Debug: 检查为什么碰撞检测不工作
        if !locationManager.isTracking {
            print("❌ 碰撞检测跳过：未在追踪状态")
            return
        }

        guard let userId = currentUserId else {
            print("❌ 碰撞检测跳过：currentUserId 为空")
            TerritoryLogger.shared.log("碰撞检测失败：用户ID为空", type: .error)
            return
        }

        print("✅ 开始执行碰撞检测，userId: \(userId)")
        print("   pathCoordinates.count: \(locationManager.pathCoordinates.count)")
        print("   territoriesManager.territories.count: \(territoryManager.territories.count)")

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else {
            print("⚠️ 路径点数不足2，跳过检测")
            return
        }

        // 获取当前位置
        guard let currentLocation = locationManager.userLocation else { return }

        let result = territoryManager.checkPathCollisionComprehensive(
            currentPoint: currentLocation.coordinate,
            path: path,
            excludeUserId: userId
        )

        // 根据预警级别处理
        switch result.warningLevel {
        case .safe:
            // 安全，隐藏警告横幅
            withAnimation {
                showCollisionWarning = false
            }
            collisionWarning = nil
            collisionWarningLevel = .safe

        case .caution:
            // 注意（50-100m）- 黄色横幅 + 轻震 1 次
            collisionWarning = result.message
            collisionWarningLevel = .caution
            withAnimation {
                showCollisionWarning = true
            }
            triggerHapticFeedback(level: .caution)

        case .warning:
            // 警告（25-50m）- 橙色横幅 + 中震 2 次
            collisionWarning = result.message
            collisionWarningLevel = .warning
            withAnimation {
                showCollisionWarning = true
            }
            triggerHapticFeedback(level: .warning)

        case .danger:
            // 危险（<25m）- 红色横幅 + 强震 3 次
            collisionWarning = result.message
            collisionWarningLevel = .danger
            withAnimation {
                showCollisionWarning = true
            }
            triggerHapticFeedback(level: .danger)

        case .violation:
            // 【关键修复】违规处理 - 必须先显示横幅，再停止！

            // 1. 先设置警告状态（让横幅显示出来）
            collisionWarning = result.message
            collisionWarningLevel = .violation
            withAnimation {
                showCollisionWarning = true
            }

            // 2. 触发震动
            triggerHapticFeedback(level: .violation)

            // 3. 只停止定时器，不清除警告状态！
            stopCollisionCheckTimer()

            // 4. 停止圈地追踪
            locationManager.stopPathTracking()
            trackingStartTime = nil

            TerritoryLogger.shared.log("碰撞违规，自动停止圈地", type: .error)

            // 5. 5秒后再清除警告横幅
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    showCollisionWarning = false
                }
                collisionWarning = nil
                collisionWarningLevel = .safe
            }
        }
    }

    /// Day 19: 触发震动反馈
    private func triggerHapticFeedback(level: WarningLevel) {
        switch level {
        case .safe:
            // 安全：无震动
            break

        case .caution:
            // 注意：轻震 1 次
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)

        case .warning:
            // 警告：中震 2 次
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }

        case .danger:
            // 危险：强震 3 次
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                generator.impactOccurred()
            }

        case .violation:
            // 违规：错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }

    /// Day 19: 碰撞警告横幅（分级颜色）
    private func collisionWarningBanner(message: String, level: WarningLevel) -> some View {
        // 根据级别确定颜色
        let backgroundColor: Color
        switch level {
        case .safe:
            backgroundColor = .green
        case .caution:
            backgroundColor = .yellow
        case .warning:
            backgroundColor = .orange
        case .danger, .violation:
            backgroundColor = .red
        }

        // 根据级别确定文字颜色（黄色背景用黑字）
        let textColor: Color = (level == .caution) ? .black : .white

        // 根据级别确定图标
        let iconName = (level == .violation) ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(textColor)

            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textColor)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }

    /// 切换探索状态（开始/结束）
    private func toggleExploration() {
        if explorationManager.isExploring {
            // 结束探索
            print("🛑 [MapTabView] 用户点击结束探索")

            // 获取探索结果
            let result = explorationManager.stopExploration()
            explorationDistance = result.distance
            explorationDuration = result.duration
            explorationTier = result.tier

            // 生成奖励
            if result.tier != .none {
                explorationRewards = RewardGenerator.shared.generateRewards(distance: result.distance)
                print("🎁 [MapTabView] 生成奖励: \(explorationRewards.count) 种物品")
            } else {
                explorationRewards = []
                print("⚠️ [MapTabView] 距离不足，无奖励")
            }

            // 显示结果页面
            showExplorationResult = true
        } else {
            // 开始探索
            print("🚀 [MapTabView] 用户点击开始探索")
            explorationManager.startExploration()
        }
    }

    /// 探索状态面板（底部深色半透明设计）
    private var explorationStatusPanel: some View {
        let currentTier = RewardGenerator.calculateTier(distance: explorationManager.totalDistance)
        let nextTierInfo = RewardGenerator.distanceToNextTier(distance: explorationManager.totalDistance)

        return VStack(spacing: 0) {
            // 信息区域
            VStack(spacing: 12) {
                // 标题行：探索进行中 + 时间
                HStack {
                    // 左侧：绿点 + 标题
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)

                        Text("探索进行中")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "999999"))
                    }

                    Spacer()

                    // 右侧：时间
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "999999"))
                        Text(explorationManager.formatDuration(explorationManager.duration))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "999999"))
                    }
                }

                // 核心数据行
                HStack(alignment: .bottom) {
                    // 左侧：行走距离
                    VStack(alignment: .leading, spacing: 4) {
                        Text("行走距离")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "999999"))

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int(explorationManager.totalDistance))")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("m")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }

                    Spacer()

                    // 右侧：奖励等级
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("奖励等级")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "999999"))

                        HStack(spacing: 6) {
                            Image(systemName: currentTier == .none ? "xmark.circle" : currentTier.icon)
                                .font(.system(size: 16))
                                .foregroundColor(currentTier == .none ? Color(hex: "999999") : currentTier.color)

                            Text(currentTier == .none ? "无奖励" : currentTier.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(currentTier == .none ? Color(hex: "999999") : currentTier.color)
                        }

                        Text("\(explorationManager.nearbyPOIs.count) 件物品")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "999999"))
                    }
                }

                // 进度条和升级提示
                VStack(spacing: 8) {
                    // 进度条
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 背景
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: "333333"))
                                .frame(height: 4)

                            // 进度 - 计算当前等级内的进度
                            let progress = calculateTierProgress(distance: explorationManager.totalDistance)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: geometry.size.width * CGFloat(progress), height: 4)
                        }
                    }
                    .frame(height: 4)

                    // 升级提示文字
                    if let next = nextTierInfo {
                        Text("再走 \(Int(next.remaining)) 米升级到 \(next.nextTier.rawValue)")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "999999"))
                    } else {
                        Text("已达最高等级!")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "999999"))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // 停止探索按钮
            Button {
                toggleExploration()
            } label: {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 14, height: 14)

                    Text("停止探索")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color(hex: "FF3B30"))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    /// 探索超速警告横幅
    private var explorationSpeedWarningBanner: some View {
        HStack(spacing: 12) {
            // 警告图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text("⚠️ 速度过快！")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    // 当前速度
                    Text("当前速度: \(String(format: "%.1f", explorationManager.currentSpeed)) km/h")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))

                    // 倒计时
                    if explorationManager.speedViolationCountdown > 0 {
                        Text("(\(explorationManager.speedViolationCountdown)秒后停止)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                }
            }

            Spacer()

            // 速度限制提示
            VStack(spacing: 2) {
                Text("限速")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Text("20")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("km/h")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.2))
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange)
                .shadow(color: .red.opacity(0.5), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }

    /// 探索失败横幅
    private var explorationFailedBanner: some View {
        HStack(spacing: 12) {
            // 失败图标
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text("探索失败")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                Text(explorationManager.errorMessage ?? "未知错误")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            // 关闭按钮
            Button {
                explorationManager.resetAfterFailure()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red)
                .shadow(color: .red.opacity(0.5), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - 错误处理

    /// 将英文错误信息转换为中文
    private func localizeError(_ errorMessage: String) -> String {
        // 常见错误的中文映射
        let errorMappings: [String: String] = [
            "foreign key constraint": "用户数据异常，请重新登录后再试",
            "territories_user_id_fkey": "用户数据异常，请重新登录后再试",
            "network": "网络连接失败，请检查网络后再试",
            "timeout": "请求超时，请稍后再试",
            "unauthorized": "登录已过期，请重新登录",
            "The Internet connection appears to be offline": "网络已断开，请检查网络连接",
            "Could not connect to the server": "无法连接到服务器，请稍后再试",
            "insert or update on table": "数据保存失败，请稍后再试"
        ]

        // 检查是否匹配已知错误
        for (key, value) in errorMappings {
            if errorMessage.lowercased().contains(key.lowercased()) {
                return value
            }
        }

        // 未知错误，返回通用提示
        return "上传失败，请稍后再试"
    }

    /// 计算当前等级内的进度 (0.0 - 1.0)
    private func calculateTierProgress(distance: Double) -> Double {
        // 等级阈值: 0-200(铜), 200-500(银), 500-1000(金), 1000-2000(钻)
        switch distance {
        case ..<200:
            return distance / 200.0
        case 200..<500:
            return (distance - 200) / 300.0
        case 500..<1000:
            return (distance - 500) / 500.0
        case 1000..<2000:
            return (distance - 1000) / 1000.0
        default:
            return 1.0 // 已达最高等级
        }
    }
}

#Preview {
    MapTabView()
        .environmentObject(LanguageManager.shared)
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
