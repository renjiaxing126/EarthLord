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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(languageManager)
                .environmentObject(locationManager)
                .environment(\.locale, languageManager.currentLocale)
        }
    }
}
