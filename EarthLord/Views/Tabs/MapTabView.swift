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
                currentUserId: currentUserId
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

                Spacer()
            }

            // 圈地按钮和确认登记按钮（右下角）
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // 确认登记按钮（验证通过时显示）
                        if locationManager.territoryValidationPassed {
                            confirmButton
                        }

                        // 圈地按钮
                        claimButton
                    }
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 100) // 避开底部 Tab Bar

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
        .onReceive(NotificationCenter.default.publisher(for: .territoryUpdated)) { _ in
            // 收到领地更新通知（删除后），刷新地图上的领地
            Task {
                await loadTerritories()
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

            // 刷新领地列表（地图上的领地）
            await loadTerritories()

            // 发送通知，让领地 Tab 也刷新
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
        guard let location = locationManager.userLocation,
              let userId = currentUserId else {
            // 没有位置或用户ID，直接开始（会在其他地方处理错误）
            trackingStartTime = Date()
            locationManager.startPathTracking()
            startCollisionMonitoring()
            return
        }

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

    /// Day 19: 启动碰撞检测监控
    private func startCollisionMonitoring() {
        // 先停止已有定时器
        stopCollisionCheckTimer()

        // 每 10 秒检测一次
        collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task { @MainActor in
                performCollisionCheck()
            }
        }

        TerritoryLogger.shared.log("碰撞检测定时器已启动", type: .info)
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
        guard locationManager.isTracking,
              let userId = currentUserId else {
            return
        }

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else { return }

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
}

#Preview {
    MapTabView()
        .environmentObject(LanguageManager.shared)
}
