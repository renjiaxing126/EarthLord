//
//  LanguageManager.swift
//  EarthLord
//
//  Created by Claude Code on 2026/1/6.
//

import SwiftUI
import Combine

/// 语言选项
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"      // 跟随系统
    case chinese = "zh-Hans"    // 简体中文
    case english = "en"         // English

    var id: String { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .system:
            return String(localized: "跟随系统")
        case .chinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }

    /// 获取对应的 Locale
    var locale: Locale {
        switch self {
        case .system:
            return Locale.current
        case .chinese:
            return Locale(identifier: "zh-Hans")
        case .english:
            return Locale(identifier: "en")
        }
    }
}

/// 语言管理器
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    /// 当前选择的语言
    @Published var currentLanguage: AppLanguage {
        didSet {
            saveLanguage()
            updateLocale()
        }
    }

    /// 当前使用的 Locale
    @Published var currentLocale: Locale

    private let userDefaultsKey = "app_selected_language"

    private init() {
        // 从 UserDefaults 读取保存的语言设置
        let savedLanguage: AppLanguage
        if let savedLanguageString = UserDefaults.standard.string(forKey: userDefaultsKey),
           let language = AppLanguage(rawValue: savedLanguageString) {
            savedLanguage = language
        } else {
            savedLanguage = .system
        }

        // 先初始化 currentLocale，再初始化 currentLanguage
        self.currentLanguage = savedLanguage
        self.currentLocale = savedLanguage.locale

        print("🌍 语言管理器初始化完成，当前语言: \(savedLanguage.displayName)")
    }

    /// 保存语言选择到 UserDefaults
    private func saveLanguage() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: userDefaultsKey)
        print("💾 保存语言设置: \(currentLanguage.displayName)")
    }

    /// 更新当前 Locale
    private func updateLocale() {
        currentLocale = currentLanguage.locale
        print("🔄 更新 Locale: \(currentLocale.identifier)")
    }

    /// 切换语言
    func switchLanguage(to language: AppLanguage) {
        print("🌐 切换语言: \(language.displayName)")
        currentLanguage = language
    }

    /// 获取本地化字符串
    func localizedString(_ key: String) -> String {
        let languageCode: String

        switch currentLanguage {
        case .system:
            languageCode = Locale.current.language.languageCode?.identifier ?? "zh-Hans"
        case .chinese:
            languageCode = "zh-Hans"
        case .english:
            languageCode = "en"
        }

        // 从 Localizable.xcstrings 读取对应语言的翻译
        // 使用 NSLocalizedString 的 bundle 参数指定语言
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let result = bundle.localizedString(forKey: key, value: nil, table: nil)
            // 如果找到翻译就返回，否则返回 key
            return result != key ? result : key
        }

        // 如果没有找到对应的 bundle，直接返回 key（显示源语言）
        return key
    }
}

/// 自定义的本地化字符串，支持 App 内语言切换
struct LocalizedText: View {
    let key: String
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        Text(languageManager.localizedString(key))
    }
}

/// 自定义的本地化 LocalizedStringKey，支持 App 内语言切换
struct AppLocalizedStringKey {
    let key: String

    init(_ key: String) {
        self.key = key
    }
}

/// View 扩展，用于便捷创建本地化文本
extension View {
    /// 创建使用 App 语言设置的本地化 Text
    func appLocalized(_ key: String) -> some View {
        LocalizedText(key: key)
    }
}

/// String 扩展，用于 App 内语言切换
extension String {
    /// 根据当前 App 语言设置获取本地化字符串
    func appLocalized(using languageManager: LanguageManager = .shared) -> String {
        return languageManager.localizedString(self)
    }

    /// 简化版本，使用全局 LanguageManager
    var appLocalized: String {
        return LanguageManager.shared.localizedString(self)
    }
}
