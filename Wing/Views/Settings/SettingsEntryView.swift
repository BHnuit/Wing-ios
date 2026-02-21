//
//  SettingsEntryView.swift
//  Wing
//
//  Created on 2026-01-29.
//

import SwiftUI
import SwiftData

/**
 * 设置入口视图 (重构版)
 * 作为设置导航的根页面
 */
struct SettingsEntryView: View {
    @Bindable private var settingsManager = SettingsManager.shared
    
    // Stats Queries
    @Query private var allSessions: [DailySession]
    @Query private var allEntries: [WingEntry]
    @Query private var allFragments: [RawFragment]
    
    // Computed Stats
    private var daysRecorded: Int {
        allSessions.filter { !$0.fragments.isEmpty }.count
    }
    
    private var todayFragments: Int {
        let today = DateFormatter.yyyyMMdd_local.string(from: Date())
        return allSessions.first { $0.date == today }?.fragments.count ?? 0
    }
    
    private var totalWings: Int {
        allFragments
            .filter { $0.type == .text }
            .reduce(0) { $0 + $1.content.count }
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
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Section 1: Statistics
                statsSection
                
                // Section 2: Features
                Section {
                    NavigationLink(destination: SettingsAIView()) {
                        Label(L("settings.ai.title"), systemImage: "bolt") // Scheme B: Geometric
                            .badge(settingsManager.appSettings?.aiProvider.rawValue.capitalized ?? "")
                    }
                    
                    NavigationLink(destination: SettingsDisplayView()) {
                        Label(L("settings.display.label"), systemImage: "rectangle.on.rectangle") // Scheme B: Geometric
                    }
                    
                    NavigationLink(destination: SettingsStorageView()) {
                        Label(L("settings.storage.label"), systemImage: "cylinder") // Scheme B: Geometric
                    }
                } header: {
                    Text(L("settings.section.features"))
                }
                
                // Section 3: Advanced
                if settingsManager.appSettings?.enableLongTermMemory == true {
                    Section {
                        NavigationLink(destination: SettingsMemoryView()) {
                            Label(L("settings.memory.label"), systemImage: "circle.hexagongrid") // Scheme B: Geometric
                        }
                    } header: {
                        Text(L("settings.section.lab"))
                    }
                }
                
                
                // Section 4: About
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(uiImage: UIImage(named: "AppIcon") ?? UIImage()) // Fallback if icon not loaded directly
                                .resizable()
                                .frame(width: 60, height: 60)
                                .cornerRadius(12)
                                .opacity(0.8)
                            
                            Text("Wing v\(appVersion)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Link(L("settings.about.privacyPolicy"), destination: privacyPolicyURL)
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .buttonStyle(.plain) // 限制点击区域仅为蓝字
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(L("settings.title"))
            .listStyle(.insetGrouped)
        }
    }
    
    private var statsSection: some View {
        Section {
            // Heatmap
            CalendarHeatmapView(sessions: allSessions)
                .padding(.vertical, 8)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            
            StatisticsView(
                daysRecorded: daysRecorded,
                todayFlaps: todayFragments,
                totalFeathers: totalWings
            )
        } header: {
            Text(L("settings.section.overview"))
        }
    }
}

// Helper for date formatting
private extension DateFormatter {
    static let yyyyMMdd_local: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

#Preview {
    SettingsEntryView()
        .environment(SettingsManager.shared) // Inject shared if needed, but better to rely on environment
        .modelContainer(for: [AppSettings.self, DailySession.self, WingEntry.self, RawFragment.self], inMemory: true)
}
