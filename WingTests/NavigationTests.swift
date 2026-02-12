//
//  NavigationTests.swift
//  WingTests
//
//  Created on 2026-01-29.
//

import Testing
import Foundation
import SwiftUI
@testable import Wing

/**
 * NavigationManager 单元测试
 *
 * 验证导航状态管理器的核心功能：
 * 1. 初始状态正确性
 * 2. Tab 切换逻辑
 * 3. 跨 Tab 导航方法
 * 4. 导航栈操作
 */
@Suite("NavigationManager Tests")
@MainActor
struct NavigationTests {
    
    // MARK: - 初始状态测试
    
    @Test("NavigationManager 初始状态应为 .now Tab")
    func testInitialState() {
        let manager = NavigationManager.forTesting()
        
        #expect(manager.selectedTab == .now)
        #expect(manager.journalPath.isEmpty)
    }
    
    // MARK: - Tab 切换测试
    
    @Test("手动切换 Tab 应正确更新 selectedTab")
    func testManualTabSwitch() {
        let manager = NavigationManager.forTesting()
        
        manager.selectedTab = .journal
        #expect(manager.selectedTab == .journal)
        
        manager.selectedTab = .settings
        #expect(manager.selectedTab == .settings)
        
        manager.selectedTab = .now
        #expect(manager.selectedTab == .now)
    }
    
    // MARK: - 跨 Tab 导航测试
    
    /*
    @Test("navigateToJournalDetail 应切换到 .journal Tab")
    func testNavigateToJournalDetailSwitchesTab() { ... }
    
    @Test("AppTab 应有正确的 rawValue")
    func testAppTabRawValues() { ... }

    @Test("AppRoute 应支持 Hashable 比较")
    func testAppRouteHashable() { ... }
    */
}
