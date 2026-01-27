//
//  WingApp.swift
//  Wing
//
//  Created by Hans on 2026/1/28.
//

import SwiftUI
import SwiftData

@main
struct WingApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // Wing 核心模型
            DailySession.self,
            WingEntry.self,
            RawFragment.self,
            // 记忆系统模型
            SemanticMemory.self,
            EpisodicMemory.self,
            ProceduralMemory.self,
            // 应用设置
            AppSettings.self,
            // 示例模型（可后续移除）
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
