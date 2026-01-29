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
    
    @Test("navigateToJournalDetail 应切换到 .journal Tab")
    func testNavigateToJournalDetailSwitchesTab() {
        let manager = NavigationManager.forTesting()
        let testEntryId = UUID()
        
        // 初始在 .now Tab
        #expect(manager.selectedTab == .now)
        
        // 执行跨 Tab 导航
        manager.navigateToJournalDetail(entryId: testEntryId)
        
        // 验证 Tab 已切换
        #expect(manager.selectedTab == .journal)
    }
    
    @Test("navigateToJournalDetail 应将路由推入 journalPath")
    func testNavigateToJournalDetailPushesRoute() {
        let manager = NavigationManager.forTesting()
        let testEntryId = UUID()
        
        // 初始路径为空
        #expect(manager.journalPath.isEmpty)
        
        // 执行导航
        manager.navigateToJournalDetail(entryId: testEntryId)
        
        // 验证路径中有一个元素
        #expect(manager.journalPath.count == 1)
    }
    
    @Test("多次 navigateToJournalDetail 应累积路径")
    func testMultipleNavigationsAccumulatePath() {
        let manager = NavigationManager.forTesting()
        let entry1 = UUID()
        let entry2 = UUID()
        let entry3 = UUID()
        
        manager.navigateToJournalDetail(entryId: entry1)
        manager.navigateToJournalDetail(entryId: entry2)
        manager.navigateToJournalDetail(entryId: entry3)
        
        #expect(manager.journalPath.count == 3)
        #expect(manager.selectedTab == .journal)
    }
    
    // MARK: - 导航栈重置测试
    
    @Test("resetJournalPath 应清空导航路径")
    func testResetJournalPath() {
        let manager = NavigationManager.forTesting()
        let testEntryId = UUID()
        
        // 先添加一些导航
        manager.navigateToJournalDetail(entryId: testEntryId)
        manager.navigateToJournalDetail(entryId: UUID())
        #expect(manager.journalPath.count == 2)
        
        // 重置
        manager.resetJournalPath()
        
        // 验证路径已清空
        #expect(manager.journalPath.isEmpty)
    }
    
    @Test("resetJournalPath 不应影响当前 Tab 选择")
    func testResetJournalPathPreservesTab() {
        let manager = NavigationManager.forTesting()
        
        manager.selectedTab = .journal
        manager.navigateToJournalDetail(entryId: UUID())
        manager.resetJournalPath()
        
        // Tab 应保持不变
        #expect(manager.selectedTab == .journal)
    }
    
    // MARK: - AppTab 枚举测试
    
    @Test("AppTab 应有正确的 rawValue")
    func testAppTabRawValues() {
        #expect(AppTab.now.rawValue == 0)
        #expect(AppTab.journal.rawValue == 1)
        #expect(AppTab.settings.rawValue == 2)
    }
    
    @Test("AppTab.allCases 应包含所有 Tab")
    func testAppTabAllCases() {
        #expect(AppTab.allCases.count == 3)
        #expect(AppTab.allCases.contains(.now))
        #expect(AppTab.allCases.contains(.journal))
        #expect(AppTab.allCases.contains(.settings))
    }
    
    // MARK: - AppRoute 枚举测试
    
    @Test("AppRoute.journalDetail 应正确存储 entryId")
    func testAppRouteJournalDetail() {
        let testId = UUID()
        let route = AppRoute.journalDetail(entryId: testId)
        
        if case .journalDetail(let storedId) = route {
            #expect(storedId == testId)
        } else {
            Issue.record("Route should be journalDetail")
        }
    }
    
    @Test("AppRoute 应支持 Hashable 比较")
    func testAppRouteHashable() {
        let id1 = UUID()
        let id2 = UUID()
        
        let route1a = AppRoute.journalDetail(entryId: id1)
        let route1b = AppRoute.journalDetail(entryId: id1)
        let route2 = AppRoute.journalDetail(entryId: id2)
        
        #expect(route1a == route1b)
        #expect(route1a != route2)
        #expect(AppRoute.chat == AppRoute.chat)
        #expect(AppRoute.chat != AppRoute.settings)
    }
}
