//
//  SettingsManager.swift
//  Wing
//
//  Created on 2026-01-29.
//

import Foundation
import SwiftData
import SwiftUI

/**
 * 设置管理器 (SettingsManager)
 *
 * 职责：
 * 1. 作为应用设置的单一真实数据源（Single Source of Truth）。
 * 2. 协调非敏感配置（存储在 SwiftData AppSettings）与敏感密钥（存储在 Keychain）。
 * 3. 提供统一的 AIConfig 生成接口供 Service 层调用。
 *
 * 使用 @Observable 宏，支持 SwiftUI 视图直接绑定。
 */
@Observable
class SettingsManager {
    static let shared = SettingsManager()
    
    /// SwiftData 模型上下文（将在初始化时由外部传入或延迟获取）
    var modelContext: ModelContext?
    
    /// 当前生效的应用设置（从数据库加载或新建默认）
    /// 注意：不要直接创建 AppSettings 实例，必须通过 fetchOrInitSettings 获取以确保只有一份
    var appSettings: AppSettings?
    
    /// 已验证通过的 Provider（内存缓存 + UserDefaults 持久化）
    var validatedProviders: Set<AiProvider> = [] {
        didSet {
            saveValidatedProviders()
        }
    }
    
    private let keychain = KeychainHelper.shared
    private let validatedProvidersKey = "WingValidatedProviders"
    
    private init() {
        // 单例模式
        loadValidatedProviders()
    }
    
    // MARK: - Initialization
    
    /**
     * 初始化设置管理器，通常在 App 启动时调用
     */
    @MainActor
    func initialize(with container: ModelContainer) {
        self.modelContext = container.mainContext
        fetchOrInitSettings()
    }
    
    /**
     * 获取或初始化 AppSettings
     * 如果数据库中没有记录，则创建一个默认配置
     */
    
    @MainActor
    private func fetchOrInitSettings() {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<AppSettings>()
            let existingSettings = try context.fetch(descriptor)
            
            if let first = existingSettings.first {
                self.appSettings = first
            } else {
                // 创建默认设置 (对齐 Web 版默认值)
                print("SettingsManager: Creating default AppSettings")
                let defaultSettings = AppSettings(
                    aiProvider: .gemini,
                    aiModels: [
                        .gemini: "gemini-3-flash",
                        .openai: "gpt-5.2",
                        .deepseek: "deepseek-chat"
                    ],
                    language: .zh, // 简配版，实际可检测 Locale.current
                    theme: .system,
                    pageFont: .system,
                    fontSize: .medium,
                    modelLanguage: .zh,
                    keepEditHistory: true,
                    backupApiKeys: true,
                    writingStyle: .prose,
                    enableLongTermMemory: false,
                    memoryExtractionAuto: true,
                    memoryRetrievalEnabled: false,
                    journalLanguage: .auto
                )
                context.insert(defaultSettings)
                try context.save()
                self.appSettings = defaultSettings
            }
        } catch {
            print("SettingsManager Error: Failed to fetch/init settings: \(error)")
        }
    }
    
    // MARK: - Persistence
    
    /**
     * 显式保存设置变更到 SwiftData
     * 在用户修改设置后调用，确保退出应用后不丢失
     */
    @MainActor
    func saveSettings() {
        guard let context = modelContext else { return }
        do {
            try context.save()
        } catch {
            print("SettingsManager Error: Failed to save settings: \(error)")
        }
    }
    
    /// 根据当前主题设置返回 ColorScheme（nil 表示跟随系统）
    var resolvedColorScheme: ColorScheme? {
        guard let theme = appSettings?.theme else { return nil }
        switch theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    /// 根据当前界面语言返回 Locale
    var resolvedLocale: Locale {
        guard let language = appSettings?.language else { return Locale.current }
        switch language {
        case .system: return Locale.current
        case .zh: return Locale(identifier: "zh-Hans")
        case .en: return Locale(identifier: "en")
        case .ja: return Locale(identifier: "ja")
        }
    }
    
    // MARK: - API Key Management (Keychain)
    
    /**
     * 异步获取指定 Provider 的 API Key
     */
    func getApiKey(for provider: AiProvider) async -> String? {
        let keyName = keychainKey(for: provider)
        return try? await keychain.loadString(for: keyName)
    }
    
    /**
     * 异步设置指定 Provider 的 API Key
     */
    func setApiKey(_ key: String, for provider: AiProvider) async {
        let keyName = keychainKey(for: provider)
        if key.isEmpty {
            try? await keychain.delete(keyName)
        } else {
            try? await keychain.save(key, for: keyName)
        }
    }
    
    private func keychainKey(for provider: AiProvider) -> String {
        return "api_key_\(provider.rawValue)"
    }
    
    /**
     * 获取当前生效的 AI 配置 (合并 Settings 与 Keychain)
     * 如果 API Key 缺失，返回 nil
     */
    func getAIConfig() async -> AIConfig? {
        guard let settings = appSettings else {
            return nil
        }
        
        let provider = settings.aiProvider
        let model = settings.aiModels[provider] ?? defaultModel(for: provider)
        let apiKey = await getApiKey(for: provider) ?? ""
        
        // 如果 API Key 为空，返回 nil
        guard !apiKey.isEmpty else {
            return nil
        }
        
        return AIConfig(
            provider: provider,
            model: model,
            apiKey: apiKey,
            baseURL: settings.aiBaseUrl
        )
    }
    
    /**
     * 安全获取日记语言设置 (避免通过 actor 边界传递 AppSettings)
     */
    @MainActor
    func getJournalLanguage() -> JournalLanguage {
        return appSettings?.journalLanguage ?? .auto
    }

    private func defaultModel(for provider: AiProvider) -> String {
        switch provider {
        case .gemini: return "gemini-3-flash"
        case .openai: return "gpt-5.2"
        case .deepseek: return "deepseek-chat"
        case .custom: return ""
        }
    }
    
    // MARK: - Validation State Persistence
    
    private func loadValidatedProviders() {
        if let data = UserDefaults.standard.data(forKey: validatedProvidersKey),
           let providers = try? JSONDecoder().decode(Set<AiProvider>.self, from: data) {
            self.validatedProviders = providers
        }
    }
    
    private func saveValidatedProviders() {
        if let data = try? JSONEncoder().encode(validatedProviders) {
            UserDefaults.standard.set(data, forKey: validatedProvidersKey)
        }
    }
}
