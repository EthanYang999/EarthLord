//
//  LanguageManager.swift
//  EarthLord
//
//  Created by Ethan on 2025/12/30.
//

import SwiftUI
import Combine

/// 支持的语言选项
enum AppLanguage: String, CaseIterable {
    case system = "system"      // 跟随系统
    case zhHans = "zh-Hans"     // 简体中文
    case en = "en"              // English

    /// 显示名称
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .zhHans: return "简体中文"
        case .en: return "English"
        }
    }

    /// 图标
    var icon: String {
        switch self {
        case .system: return "iphone"
        case .zhHans: return "character.zh"
        case .en: return "character.en"
        }
    }
}

/// 语言管理器
/// 负责 App 内语言切换，不依赖系统语言设置
@MainActor
class LanguageManager: ObservableObject {

    /// 单例
    static let shared = LanguageManager()

    /// 存储 key
    private let languageKey = "app_language"

    /// 当前选择的语言选项
    @Published var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: languageKey)
            updateBundle()
        }
    }

    /// 当前使用的语言 Bundle
    @Published private(set) var bundle: Bundle = .main

    /// 用于强制刷新 UI 的 ID
    @Published var refreshID = UUID()

    private init() {
        // 从 UserDefaults 读取保存的语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.selectedLanguage = language
        } else {
            self.selectedLanguage = .system
        }
        updateBundle()
    }

    /// 更新语言 Bundle
    private func updateBundle() {
        let languageCode: String

        switch selectedLanguage {
        case .system:
            // 跟随系统：使用系统首选语言
            languageCode = Locale.preferredLanguages.first ?? "en"
        case .zhHans:
            languageCode = "zh-Hans"
        case .en:
            languageCode = "en"
        }

        // 尝试找到对应语言的 bundle
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let languageBundle = Bundle(path: path) {
            bundle = languageBundle
        } else if let path = Bundle.main.path(forResource: "Base", ofType: "lproj"),
                  let baseBundle = Bundle(path: path) {
            bundle = baseBundle
        } else {
            bundle = .main
        }

        // 触发 UI 刷新
        refreshID = UUID()
    }

    /// 获取本地化字符串
    func localizedString(_ key: String) -> String {
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// 切换语言
    func setLanguage(_ language: AppLanguage) {
        selectedLanguage = language
    }
}

// MARK: - String Extension for Localization

extension String {
    /// 根据当前 App 语言设置获取本地化字符串
    var localized: String {
        return LanguageManager.shared.localizedString(self)
    }

    /// 带参数的本地化字符串
    func localized(_ args: CVarArg...) -> String {
        let format = LanguageManager.shared.localizedString(self)
        return String(format: format, arguments: args)
    }
}

// MARK: - View Modifier for Language

/// 语言环境修饰器
struct LanguageEnvironment: ViewModifier {
    @ObservedObject var languageManager = LanguageManager.shared

    func body(content: Content) -> some View {
        content
            .id(languageManager.refreshID)
            .environment(\.locale, Locale(identifier: languageManager.selectedLanguage == .system
                ? Locale.preferredLanguages.first ?? "en"
                : languageManager.selectedLanguage.rawValue))
    }
}

extension View {
    /// 应用语言环境
    func withLanguageEnvironment() -> some View {
        modifier(LanguageEnvironment())
    }
}
