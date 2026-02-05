//
//  SettingsDisplayView.swift
//  Wing
//
//  Created on 2026-02-05.
//

import SwiftUI

struct SettingsDisplayView: View {
    @Bindable var settingsManager = SettingsManager.shared
    
    // 临时状态，后续可移入 AppSettings
    @AppStorage("appTheme") private var appTheme: Theme = .system
    @AppStorage("pageFont") private var pageFont: PageFont = .system
    @AppStorage("fontSize") private var fontSize: FontSize = .medium
    
    var body: some View {
        Form {
            if let settings = settingsManager.appSettings {
                Section {
                    Picker("日记语言", selection: Binding(
                        get: { settings.journalLanguage },
                        set: { settings.journalLanguage = $0 }
                    )) {
                        ForEach(JournalLanguage.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                } header: {
                    Text("语言配置")
                } footer: {
                    Text("AI 生成日记时使用的语言。选择'自动'将跟随碎片内容的语言。")
                }
                
                Section {
                    Picker("主题模式", selection: $appTheme) {
                        Text("跟随系统").tag(Theme.system)
                        Text("浅色").tag(Theme.light)
                        Text("深色").tag(Theme.dark)
                    }
                    
                    Picker("字体选择", selection: $pageFont) {
                        Text("系统默认").tag(PageFont.system)
                        Text("思源黑体").tag(PageFont.sourceHanSans)
                        Text("思源宋体").tag(PageFont.sourceHanSerif)
                        Text("霞鹜文楷").tag(PageFont.xlwk)
                    }
                    
                    Picker("字号大小", selection: $fontSize) {
                        Text("小").tag(FontSize.small)
                        Text("中").tag(FontSize.medium)
                        Text("大").tag(FontSize.large)
                    }
                } header: {
                    Text("外观样式")
                }
            }
        }
        .navigationTitle("显示选项")
        .navigationBarTitleDisplayMode(.inline)
    }
}
