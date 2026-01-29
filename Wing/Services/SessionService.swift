//
//  SessionService.swift
//  Wing
//
//  Created on 2026-01-29.
//

import Foundation
import SwiftData

/**
 * DailySession 服务
 *
 * 职责：
 * 1. 获取或创建今日 Session
 * 2. 按日期查询历史 Session
 * 3. 添加碎片到 Session
 * 4. 处理跨天逻辑
 */
actor SessionService {
    
    // MARK: - Session CRUD
    
    /**
     * 获取或创建指定日期的 Session
     *
     * @param date 日期字符串（YYYY-MM-DD）
     * @param context SwiftData ModelContext
     * @return DailySession
     */
    func getOrCreateSession(for date: String, context: ModelContext) -> DailySession {
        // 查询是否已存在该日期的 Session
        let descriptor = FetchDescriptor<DailySession>(
            predicate: #Predicate { $0.date == date }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        // 不存在则创建新 Session
        let newSession = DailySession(
            date: date,
            status: .recording
        )
        context.insert(newSession)
        
        return newSession
    }
    
    /**
     * 获取今日 Session（自动创建）
     */
    func getTodaySession(context: ModelContext) -> DailySession {
        let today = getCurrentDateString()
        return getOrCreateSession(for: today, context: context)
    }
    
    /**
     * 按日期获取 Session（不自动创建）
     */
    func getSession(for date: String, context: ModelContext) -> DailySession? {
        let descriptor = FetchDescriptor<DailySession>(
            predicate: #Predicate { $0.date == date }
        )
        return try? context.fetch(descriptor).first
    }
    
    // MARK: - Fragment Operations
    
    /**
     * 添加文本碎片到 Session
     */
    func addTextFragment(_ text: String, to session: DailySession, context: ModelContext) {
        let fragment = RawFragment(
            content: text,
            timestamp: getCurrentTimestamp(),
            type: .text
        )
        
        fragment.dailySession = session
        session.fragments.append(fragment)
        context.insert(fragment)
    }
    
    /**
     * 添加图片碎片到 Session
     *
     * @param imageData 压缩后的图片数据
     * @param caption 可选的图片描述
     */
    func addImageFragment(
        _ imageData: Data,
        caption: String = "",
        to session: DailySession,
        context: ModelContext
    ) {
        let fragment = RawFragment(
            content: caption,
            imageData: imageData,
            timestamp: getCurrentTimestamp(),
            type: .image
        )
        
        fragment.dailySession = session
        session.fragments.append(fragment)
        context.insert(fragment)
    }
    
    /**
     * 更新碎片内容（用于编辑）
     */
    func updateFragment(_ fragment: RawFragment, newContent: String) {
        fragment.content = newContent
        fragment.editedAt = getCurrentTimestamp()
    }
    
    /**
     * 删除碎片
     */
    func deleteFragment(_ fragment: RawFragment, context: ModelContext) {
        context.delete(fragment)
    }
    
    // MARK: - Helper Methods
    
    /**
     * 获取当前日期字符串（YYYY-MM-DD）
     */
    private func getCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }
    
    /**
     * 获取当前时间戳（Unix 毫秒）
     */
    private func getCurrentTimestamp() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}
