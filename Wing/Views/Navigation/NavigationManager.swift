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
    case journal = 1   // 日记
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
    
    /// 控制半屏输入 Sheet（"当下"按钮触发）
    var showComposer: Bool = false
    
    /// Composer Sheet 的当前高度状态（用于 ChatView 避让）
    var composerDetent: PresentationDetent = .fraction(0.25)
    
    // MARK: - Synthesis State
    
    /// 是否正在合成日记（用于控制 TabBar 动画）
    var isSynthesizing: Bool = false
    
    /// 合成进度（后端处理阶段）
    var synthesisProgress: SynthesisProgress = .started
    
    /// 获取合成进度的可视化数值 (0.0 - 1.0)
    var synthesisProgressValue: Double {
        switch synthesisProgress {
        case .started: return 0.05
        case .generating: return 0.4
        case .saving: return 0.8
        case .completed: return 1.0
        case .failed: return 0.0
        }
    }
    
    /// 长按蓄力进度 (0.0 - 1.0)
    /// 用于驱动气泡高亮和 TabBar 上的进度环
    var chargingProgress: Double = 0.0
    
    /// 气泡位置列表 (用于发散粒子)
    var bubbleAnchors: [CGRect] = []
    
    /// 日记图标位置 (用于接收粒子)
    var journalIconAnchor: CGRect = .zero
    
    /// 是否处于长按蓄力状态
    var isCharging: Bool {
        return chargingProgress > 0 && chargingProgress < 1.0
    }
    
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
    
    // MARK: - UI State Helpers
    
    /**
     * 是否应该显示 TabBar
     *
     * 逻辑：
     * 1. 如果正在合成，为了防止误触，可以隐藏或禁用（这里选择不隐藏但禁用，由 View 层处理禁用）
     * 2. 如果在日记详情页（journalPath 不为空），必须隐藏 TabBar 以免遮挡
     */
    var shouldShowTabBar: Bool {
        // 如果在回忆 Tab 且有导航堆栈（即进入了详情页），则隐藏 TabBar
        if selectedTab == .journal && !journalPath.isEmpty {
            return false
        }
        return true
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

// MARK: - Anchor Preference Keys

/// 收集目标图标（回忆 Tab）的位置
/// 收集目标图标（回忆 Tab）的位置
struct JournalIconAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue()
    }
}

/// 收集所有可见气泡的位置
struct BubbleAnchorKey: PreferenceKey {
    static var defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}
