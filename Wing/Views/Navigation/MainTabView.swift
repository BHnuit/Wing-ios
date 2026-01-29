//
//  MainTabView.swift
//  Wing
//
//  Created on 2026-01-29.
//

import SwiftUI
import SwiftData

/**
 * 主 Tab 视图
 *
 * Wing 应用的主导航容器，包含三个核心 Tab：
 * - 当下（Now）：聊天/记录界面
 * - 回忆（Journal）：日记列表与详情
 * - 设置（Settings）：应用配置
 */
struct MainTabView: View {
    @State private var navigationManager = NavigationManager()
    
    var body: some View {
        TabView(selection: $navigationManager.selectedTab) {
            // Tab 1: 当下
            NowTabView()
                .tabItem {
                    Label("当下", systemImage: "sparkles")
                }
                .tag(AppTab.now)
            
            // Tab 2: 回忆
            JournalTabView()
                .tabItem {
                    Label("回忆", systemImage: "book.closed")
                }
                .tag(AppTab.journal)
            
            // Tab 3: 设置
            SettingsTabView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .environment(navigationManager)
        .environment(SettingsManager.shared)
    }
}

// MARK: - Tab Content Views (Placeholders)

/**
 * 当下 Tab 视图
 *
 * 显示完整的 ChatView 聊天记录界面
 */
private struct NowTabView: View {
    var body: some View {
        ChatView()
    }
}

/**
 * 回忆 Tab 视图
 *
 * 包含 NavigationStack 以支持推入日记详情页
 */
private struct JournalTabView: View {
    @Environment(NavigationManager.self) private var navigationManager
    @Query(sort: \WingEntry.createdAt, order: .reverse) private var entries: [WingEntry]
    
    var body: some View {
        @Bindable var navManager = navigationManager
        
        NavigationStack(path: $navManager.journalPath) {
            List {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "暂无日记",
                        systemImage: "book.closed",
                        description: Text("从\"当下\"记录你的想法，生成第一篇日记")
                    )
                } else {
                    ForEach(entries) { entry in
                        NavigationLink(value: AppRoute.journalDetail(entryId: entry.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(entry.mood)
                                        .font(.title2)
                                    Text(entry.title)
                                        .font(.headline)
                                }
                                Text(entry.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("回忆")
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .journalDetail(let entryId):
                    JournalDetailPlaceholderView(entryId: entryId)
                default:
                    Text("未知路由")
                }
            }
        }
    }
}

/**
 * 日记详情占位视图
 *
 * Phase 6 将实现完整的 Markdown 渲染和详情页
 */
private struct JournalDetailPlaceholderView: View {
    let entryId: UUID
    @Query private var entries: [WingEntry]
    
    private var entry: WingEntry? {
        entries.first { $0.id == entryId }
    }
    
    var body: some View {
        ScrollView {
            if let entry = entry {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(entry.mood)
                            .font(.system(size: 48))
                        Spacer()
                    }
                    
                    Text(entry.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(entry.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Divider()
                    
                    Text(entry.markdownContent)
                        .font(.body)
                    
                    if !entry.aiInsights.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("猫头鹰的洞察", systemImage: "brain.head.profile")
                                .font(.headline)
                            
                            Text(entry.aiInsights)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            } else {
                ContentUnavailableView(
                    "日记不存在",
                    systemImage: "exclamationmark.triangle",
                    description: Text("无法找到该日记")
                )
            }
        }
        .navigationTitle("日记详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/**
 * 设置 Tab 视图
 *
 * 复用现有的 SettingsEntryView
 */
private struct SettingsTabView: View {
    var body: some View {
        NavigationStack {
            SettingsEntryView()
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [
            DailySession.self,
            WingEntry.self,
            RawFragment.self,
            SemanticMemory.self,
            EpisodicMemory.self,
            ProceduralMemory.self,
            AppSettings.self
        ], inMemory: true)
}
