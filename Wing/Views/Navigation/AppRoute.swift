//
//  AppRoute.swift
//  Wing
//
//  Created on 2026-01-29.
//

import Foundation

/**
 * 应用路由枚举
 *
 * 定义 Wing 应用中的所有路由类型，用于 NavigationStack 和跨 Tab 导航。
 */
enum AppRoute: Hashable {
    /// 当下（聊天/记录界面）
    case chat
    
    /// 回忆列表
    case journalList
    
    /// 日记详情（传递 Entry ID 而非整个对象，避免 @Model 类的 Hashable 复杂性）
    case journalDetail(entryId: UUID)
    
    /// 设置
    case settings
}
