//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by yanshuang ren on 2026/1/3.
//

import SwiftUI

@main
struct EarthLordApp: App {
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var locationManager = LocationManager.shared

    /// App生命周期环境
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 触发 BuildingManager 初始化和模板加载
        _ = BuildingManager.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(languageManager)
                .environmentObject(locationManager)
                .environment(\.locale, languageManager.currentLocale)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    /// 处理App生命周期变化
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App变为活跃状态（前台）
            print("📱 [App] 进入前台")
            handleAppBecameActive()

        case .inactive:
            // App变为非活跃状态（切换中）
            print("📱 [App] 变为非活跃")

        case .background:
            // App进入后台
            print("📱 [App] 进入后台")
            handleAppEnteredBackground()

        @unknown default:
            break
        }
    }

    /// App变为活跃状态时的处理
    private func handleAppBecameActive() {
        // 如果有位置，上报一次
        Task {
            if let location = locationManager.userLocation {
                await PlayerLocationManager.shared.reportLocation(location)
                print("✅ [App] 前台位置上报完成")
            }
        }
    }

    /// App进入后台时的处理
    private func handleAppEnteredBackground() {
        // 标记玩家离线
        Task {
            await PlayerLocationManager.shared.markOffline()
            print("✅ [App] 已标记为离线")
        }

        // 如果正在探索，停止定时上报（但不停止探索）
        // 探索状态会在用户回到App时继续
        PlayerLocationManager.shared.stopPeriodicReporting()
    }
}
