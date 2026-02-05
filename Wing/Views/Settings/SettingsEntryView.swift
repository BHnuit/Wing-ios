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
    
    // Computed Stats
    private var daysRecorded: Int {
        allSessions.count
    }
    
    private var todayFragments: Int {
        let today = DateFormatter.yyyyMMdd_local.string(from: Date())
        return allSessions.first { $0.date == today }?.fragments.count ?? 0
    }
    
    private var totalWings: Int {
        allEntries.count
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Section 1: Statistics
                statsSection
                
                // Section 2: Features
                Section {
                    NavigationLink(destination: SettingsAIView()) {
                        Label("模型配置", systemImage: "cpu")
                            .badge(settingsManager.appSettings?.aiProvider.rawValue.capitalized ?? "")
                    }
                    
                    NavigationLink(destination: SettingsDisplayView()) {
                        Label("显示选项", systemImage: "textformat.size")
                    }
                    
                    NavigationLink(destination: SettingsStorageView()) {
                        Label("存储管理", systemImage: "externaldrive")
                    }
                } header: {
                    Text("功能")
                }
                
                // Section 3: Advanced
                if settingsManager.appSettings?.enableLongTermMemory == true {
                    Section {
                        NavigationLink(destination: SettingsMemoryView()) {
                            Label("记忆管理", systemImage: "brain.head.profile")
                        }
                    } header: {
                        Text("实验室")
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
            .navigationTitle("设置")
            .listStyle(.insetGrouped)
        }
    }
    
    private var statsSection: some View {
        Section {
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("\(daysRecorded)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("已记录天数")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                VStack(alignment: .leading) {
                    Text("\(todayFragments)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("今日碎片")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                VStack(alignment: .leading) {
                    Text("\(totalWings)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("累计日记")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
        } header: {
            Text("概览")
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
        .modelContainer(for: [AppSettings.self, DailySession.self], inMemory: true)
        .onAppear {
            SettingsManager.shared.initialize(with: try! ModelContainer(for: AppSettings.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        }
}
