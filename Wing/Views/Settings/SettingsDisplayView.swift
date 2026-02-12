//
//  SettingsDisplayView.swift
//  Wing
//
//  Created on 2026-02-05.
//

import SwiftUI

struct SettingsDisplayView: View {
    @Bindable var settingsManager = SettingsManager.shared
    
    var body: some View {
        Form {
            if let settings = settingsManager.appSettings {
                Section {
                    Picker(L("settings.display.journalLang"), selection: Binding(
                        get: { settings.journalLanguage },
                        set: {
                            settings.journalLanguage = $0
                            settingsManager.saveSettings()
                        }
                    )) {
                        ForEach(JournalLanguage.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                } header: {
                    Text(L("settings.display.section.journalLang"))
                } footer: {
                    Text(L("settings.display.journalLang.footer"))
                }
                
                Section {
                    Picker(L("settings.display.uiLang"), selection: Binding(
                        get: { settings.language },
                        set: {
                            settings.language = $0
                            settingsManager.saveSettings()
                        }
                    )) {
                        ForEach(Language.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                } header: {
                    Text(L("settings.display.section.uiLang"))
                } footer: {
                    Text(L("settings.display.uiLang.footer"))
                }
                
                Section {
                    Picker(L("settings.display.theme"), selection: Binding(
                        get: { settings.theme },
                        set: {
                            settings.theme = $0
                            settingsManager.saveSettings()
                            // 切换主题时添加触觉反馈
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    )) {
                        Text(L("settings.display.theme.system")).tag(Theme.system)
                        Text(L("settings.display.theme.light")).tag(Theme.light)
                        Text(L("settings.display.theme.dark")).tag(Theme.dark)
                    }
                    
                    Picker(L("settings.display.fontSize"), selection: Binding(
                        get: { settings.fontSize },
                        set: {
                            settings.fontSize = $0
                            settingsManager.saveSettings()
                        }
                    )) {
                        Text(L("settings.display.fontSize.small")).tag(FontSize.small)
                        Text(L("settings.display.fontSize.medium")).tag(FontSize.medium)
                        Text(L("settings.display.fontSize.large")).tag(FontSize.large)
                    }
                } header: {
                    Text(L("settings.display.section.appearance"))
                }
            }
        }
        .navigationTitle(L("settings.display.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
