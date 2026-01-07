//
//  MapTabView.swift
//  EarthLord
//
//  Created by yanshuang ren on 2026/1/4.
//

import SwiftUI
import MapKit

struct MapTabView: View {
    @StateObject private var locationManager = LocationManager.shared
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showSpeedWarning = false
    @State private var showValidationBanner = false

    var body: some View {
        ZStack {
            // 地图视图
            MapViewRepresentable(
                locationManager: locationManager,
                trackingPath: $locationManager.pathCoordinates,
                pathUpdateVersion: locationManager.pathUpdateVersion,
                isTracking: locationManager.isTracking,
                isPathClosed: locationManager.isPathClosed
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

                Spacer()
            }

            // 圈地按钮（右下角）
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    claimButton
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

    /// 圈地按钮
    private var claimButton: some View {
        Button {
            if locationManager.isTracking {
                // 停止追踪
                locationManager.stopPathTracking()
            } else {
                // 开始追踪
                locationManager.startPathTracking()
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
}

#Preview {
    MapTabView()
        .environmentObject(LanguageManager.shared)
}
