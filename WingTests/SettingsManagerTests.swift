//
//  SettingsManagerTests.swift
//  WingTests
//
//  Created on 2026-01-29.
//

import Testing
import SwiftData
import Foundation
@testable import Wing

@Suite("SettingsManager Tests")
@MainActor
struct SettingsManagerTests {
    
    // 用独特的 Key 防止污染真实 Keychain
    let testProvider = AiProvider.custom
    let testKey = "test_secret_key_12345"
    
    @Test("Initialize creates default settings")
    func testInitialization() async throws {
        // 1. Setup In-Memory Container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AppSettings.self, configurations: config)
        
        // 2. Initialize Manager
        let manager = SettingsManager.shared
        await manager.initialize(with: container)
        
        // 3. Verify Defaults
        let settings = manager.appSettings
        #expect(settings != nil)
        #expect(settings?.aiProvider == .gemini)
        #expect(settings?.writingStyle == .prose)
        #expect(settings?.aiModels[.gemini] == "gemini-2.5-flash")
    }
    
    @Test("Keychain Integration")
    func testKeychainIntegration() async throws {
        let manager = SettingsManager.shared
        
        // 1. Set Key
        await manager.setApiKey(testKey, for: testProvider)
        
        // 2. Get Key
        let fetchedKey = await manager.getApiKey(for: testProvider)
        #expect(fetchedKey == testKey)
        
        // 3. Delete Key (Cleanup)
        await manager.setApiKey("", for: testProvider)
        let deletedKey = await manager.getApiKey(for: testProvider)
        #expect(deletedKey == nil)
    }
    
    @Test("AIConfig Assembly")
    func testAIConfigAssembly() async throws {
        // 1. Setup In-Memory Container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AppSettings.self, configurations: config)
        
        let manager = SettingsManager.shared
        await manager.initialize(with: container)
        
        // 2. Set Test Data
        let settings = manager.appSettings
        settings?.aiProvider = .openai
        settings?.aiModels[.openai] = "gpt-4o-test-model"
        
        let openAIKey = "sk-test-openai-key"
        await manager.setApiKey(openAIKey, for: .openai)
        
        // 3. Get Config
        let configObj = await manager.getAIConfig()
        
        // 4. Verify
        // 4. Verify
        #expect(configObj?.provider == .openai)
        #expect(configObj?.model == "gpt-4o-test-model")
        #expect(configObj?.apiKey == openAIKey)
        
        // Cleanup
        await manager.setApiKey("", for: .openai)
    }
}
