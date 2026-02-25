//
//  SettingsAboutView.swift
//  Wing
//
//  Created on 2026-02-25.
//

import SwiftUI
import SwiftData

/**
 * 设置 - 关于页面
 *
 * 包含：
 * - App Icon + 本地化应用名 + 版本号
 * - 隐私政策（根据语言自动跳转）
 * - 显示引导（重置 Onboarding）
 * - AI 数据共享同意管理
 */
struct SettingsAboutView: View {
    @Bindable private var settingsManager = SettingsManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = true
    
    @State private var showDataSharingConsent: Bool = false
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var privacyPolicyURL: URL {
        let langCode = settingsManager.appSettings?.language.rawValue ?? "system"
        let actualLang: String
        
        if langCode == "system" {
            actualLang = Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            actualLang = langCode
        }
        
        let urlString: String
        if actualLang.hasPrefix("zh") {
            urlString = "https://BHnuit.github.io/Wing-ios/privacy-zh.html"
        } else if actualLang.hasPrefix("ja") {
            urlString = "https://BHnuit.github.io/Wing-ios/privacy-ja.html"
        } else {
            urlString = "https://BHnuit.github.io/Wing-ios/privacy.html"
        }
        
        return URL(string: urlString)!
    }
    
    var body: some View {
        List {
            // App Icon + 版本
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image("AppIconDisplay")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .primary.opacity(0.08), radius: 8, y: 2)
                        
                        Text("\(L("app.name")) v\(appVersion)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .padding(.vertical, 8)
            }
            
            // 功能区
            Section {
                // 隐私政策
                Link(destination: privacyPolicyURL) {
                    Label(L("settings.about.privacyPolicy"), systemImage: "lock.shield")
                }
                
                // 显示引导
                Button {
                    withAnimation {
                        hasCompletedOnboarding = false
                    }
                } label: {
                    Label(L("settings.about.showOnboarding"), systemImage: "arrow.counterclockwise")
                }
                
                // AI 数据共享
                HStack {
                    Label(L("settings.privacy.dataSharing"), systemImage: "hand.raised")
                    Spacer()
                    if settingsManager.appSettings?.hasConsentedDataSharing == true {
                        Text(L("settings.privacy.consented"))
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text(L("settings.privacy.notConsented"))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                
                // 撤回同意
                if settingsManager.appSettings?.hasConsentedDataSharing == true {
                    Button(role: .destructive) {
                        settingsManager.appSettings?.hasConsentedDataSharing = false
                        try? settingsManager.modelContext?.save()
                    } label: {
                        Label(L("settings.privacy.revoke"), systemImage: "xmark.shield")
                    }
                }
            } footer: {
                Text(L("settings.privacy.footer"))
            }
        }
        .navigationTitle(L("settings.about.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsAboutView()
    }
}
