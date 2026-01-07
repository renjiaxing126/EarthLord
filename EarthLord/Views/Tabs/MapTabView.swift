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

    var body: some View {
        ZStack {
            // 地图视图
            MapViewRepresentable(locationManager: locationManager)
                .ignoresSafeArea()

            // 顶部状态栏
            VStack {
                statusBar
                Spacer()
            }

            // 权限请求或错误提示
            if locationManager.isDenied {
                permissionDeniedView
            } else if locationManager.authorizationStatus == .notDetermined {
                permissionRequestView
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
