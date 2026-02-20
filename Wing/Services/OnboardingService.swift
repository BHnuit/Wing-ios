//
//  OnboardingService.swift
//  Wing
//
//  Created on \(Date().formatted(.iso8601.year().month().day())).
//

import Foundation
import SwiftData
import SwiftUI

/// 管理新用户启动引导相关逻辑的服务
@MainActor
final class OnboardingService {
    static let shared = OnboardingService()
    
    private init() {}
    
    /// 当不存在任何 Session 时，自动创建第一篇欢迎日记。
    func createWelcomeEntryIfNeeded(context: ModelContext) throws {
        // 检查是否已经存在 DailySession（代表用户至少已经有过使用痕迹或已经生成过引导日记）
        let descriptor = FetchDescriptor<DailySession>()
        let count = try context.fetchCount(descriptor)
        
        guard count == 0 else {
            return
        }
        
        // 生成今日的虚拟会话
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayDateStr = formatter.string(from: Date())
        
        let session = DailySession(date: todayDateStr, status: .completed)
        context.insert(session)
        
        // TODO 构建
        let todo1 = WingTodo(title: String(localized: "welcome.entry.todo1"), priority: .medium, completed: true)
        let todo2 = WingTodo(title: String(localized: "welcome.entry.todo2"), priority: .high, completed: false)
        let todos = [todo1, todo2]
        
        // 构建欢迎日记
        let entry = WingEntry(
            id: UUID(),
            title: String(localized: "welcome.entry.title"),
            summary: String(localized: "welcome.entry.summary"),
            mood: String(localized: "welcome.entry.mood"),
            markdownContent: String(localized: "welcome.entry.content"),
            aiInsights: String(localized: "welcome.entry.insight"),
            todos: todos,
            createdAt: Int64(Date().timeIntervalSince1970 * 1000),
            editedAt: nil,
            editHistory: [],
            generatedAt: Int64(Date().timeIntervalSince1970 * 1000),
            images: [:]
        )
        
        entry.dailySession = session
        session.finalEntryId = entry.id
        session.finalEntry = entry
        
        context.insert(entry)
        try context.save()
    }
}
