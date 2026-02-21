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
        
        // 强制隐藏原生 TabBar 背景，防止“鬼影”
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        // 同时移除阴影
        appearance.shadowImage = UIImage()
        appearance.backgroundImage = UIImage()
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    @Bindable private var settingsManager = SettingsManager.shared
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .appFont()
                    .preferredColorScheme(settingsManager.resolvedColorScheme)
                    .environment(\.locale, settingsManager.resolvedLocale)
                    .environment(settingsManager)
                
                if showSplash {
                    SplashScreenView {
                        showSplash = false
                    }
                    .transition(.opacity)
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
