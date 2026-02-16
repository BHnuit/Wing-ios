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
        allSessions.count
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
                            
                            Text("Wing v0.2.1")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
            
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("\(daysRecorded)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(L("settings.stats.daysRecorded"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                VStack(alignment: .leading) {
                    Text("\(todayFragments)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(L("settings.stats.todayFlaps"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                VStack(alignment: .leading) {
                    Text("\(totalWings)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(L("settings.stats.totalFeathers"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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
