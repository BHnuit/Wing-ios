//
//  NavigationManager.swift
//  Wing
//
//  Created on 2026-01-29.
//

import Foundation
import SwiftUI

/**
 * Tab 枚举
 */
enum AppTab: Int, CaseIterable, Codable {
    case now = 0       // 当下
    case journal = 1   // 回忆
    case settings = 2  // 设置
}

// MARK: - Navigation State Persistence Keys

private enum NavigationStorageKeys {
    static let selectedTab = "wing_selected_tab"
}

/**
 * 导航管理器
 *
 * 职责：
 * 1. 管理 Tab 选择状态
 * 2. 管理"回忆"Tab 的 NavigationStack 路径
 * 3. 提供跨 Tab 导航方法（如从"当下"合成日记后跳转到详情页）
 * 4. 支持状态恢复（State Restoration）—— Tab 选择会持久化
 *
 * 使用 @Observable 宏，支持 SwiftUI 视图直接绑定。
 */
@Observable
class NavigationManager {
    /// 当前选中的 Tab
    var selectedTab: AppTab = .now {
        didSet {
            if persistState {
                UserDefaults.standard.set(selectedTab.rawValue, forKey: NavigationStorageKeys.selectedTab)
            }
        }
    }
    
    /// 回忆 Tab 的导航路径（仅此 Tab 需要深层导航）
    /// 注意：NavigationPath 不持久化，重启后回到列表页是合理的 UX
    var journalPath = NavigationPath()
    
    /// 是否启用状态恢复（测试时可禁用）
    @ObservationIgnored
    private let persistState: Bool
    
    // MARK: - Initialization
    
    init(persistState: Bool = true) {
        self.persistState = persistState
        
        if persistState {
            // 恢复 Tab 选择
            let savedTabRaw = UserDefaults.standard.integer(forKey: NavigationStorageKeys.selectedTab)
            if let savedTab = AppTab(rawValue: savedTabRaw) {
                self.selectedTab = savedTab
            }
        }
    }
    
    // MARK: - Navigation Methods
    
    /**
     * 跨 Tab 跳转到日记详情
     *
     * 使用场景：从"当下"Tab 合成日记后，自动切换到"回忆"Tab 并推入详情页
     */
    func navigateToJournalDetail(entryId: UUID) {
        journalPath.append(AppRoute.journalDetail(entryId: entryId))
        selectedTab = .journal
    }
    
    /**
     * 重置回忆 Tab 的导航栈
     *
     * 使用场景：用户切换到其他 Tab 后，可选择清空回忆 Tab 的历史栈
     */
    func resetJournalPath() {
        journalPath = NavigationPath()
    }
}

// MARK: - Testing Support

extension NavigationManager {
    /**
     * 创建一个不持久化状态的测试实例
     */
    static func forTesting() -> NavigationManager {
        return NavigationManager(persistState: false)
    }
}
