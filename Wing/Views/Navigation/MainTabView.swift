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
                    Label(L("tab.now"), systemImage: "sparkles")
                }
                .tag(AppTab.now)
            
            // Tab 2: 回忆
            JournalTabView()
                .tabItem {
                    Label(L("tab.journal"), systemImage: "book.closed")
                }
                .tag(AppTab.journal)
            
            // Tab 3: 设置
            SettingsTabView()
                .tabItem {
                    Label(L("tab.settings"), systemImage: "gearshape")
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
                        L("journal.empty"),
                        systemImage: "book.closed",
                        description: Text(L("journal.empty.hint"))
                    )
                } else {
                    ForEach(entries) { entry in
                        NavigationLink(value: AppRoute.journalDetail(entryId: entry.id)) {
                            HStack {
                                Text(entry.mood)
                                    .font(.title2)
                                Text(entry.title)
                                    .font(.headline)
                                Spacer()
                                // 右侧日期（优先使用 session.date，fallback 到 createdAt）
                                Text(formatEntryDate(entry))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(L("journal.title"))
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .journalDetail(let entryId):
                    JournalDetailView(entryId: entryId)
                default:
                    Text(L("journal.unknown.route"))
                }
            }
        }
    }
    
    /// 格式化日记日期 (MM/dd)
    private func formatEntryDate(_ entry: WingEntry) -> String {
        // 优先使用 session.date
        if let dateString = entry.dailySession?.date {
            return formatListDate(dateString)
        }
        
        // Fallback: 使用 createdAt 时间戳
        let date = Date(timeIntervalSince1970: TimeInterval(entry.createdAt) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    /// 格式化日期字符串 (MM/dd)
    private func formatListDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
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
