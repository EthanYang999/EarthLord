//
//  LanguageSettingsView.swift
//  EarthLord
//
//  Created by Ethan on 2025/12/30.
//

import SwiftUI

/// 语言设置页面
struct LanguageSettingsView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    languageRow(language)
                }
            } footer: {
                Text("language_setting_footer".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("language_setting_title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 语言选项行
    private func languageRow(_ language: AppLanguage) -> some View {
        Button {
            withAnimation {
                languageManager.setLanguage(language)
            }
        } label: {
            HStack {
                // 图标
                Image(systemName: language.icon)
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(width: 32)

                // 语言名称
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .foregroundColor(.primary)

                    if language == .system {
                        Text("language_system_desc".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // 选中标记
                if languageManager.selectedLanguage == language {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                        .font(.title2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
}
