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

    init() {
        // 初始化设置管理器
        SettingsManager.shared.initialize(with: sharedModelContainer)
        
        // 注入测试数据（仅在开发阶段，且数据库为空时）
        #if DEBUG
        let container = sharedModelContainer
        Task { @MainActor in
            let context = container.mainContext
            let injector = TestDataInjector()
            await injector.injectTestData(context: context)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
