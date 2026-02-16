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
    nonisolated func getOrCreateSession(for date: String, context: ModelContext) -> DailySession {
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
    nonisolated func getTodaySession(context: ModelContext) -> DailySession {
        let today = getCurrentDateString()
        return getOrCreateSession(for: today, context: context)
    }
    
    /**
     * 获取指定日期的 Session（不自动创建）
     */
    nonisolated func getSession(for date: String, context: ModelContext) -> DailySession? {
        let descriptor = FetchDescriptor<DailySession>(
            predicate: #Predicate { $0.date == date }
        )
        return try? context.fetch(descriptor).first
    }
    
    /**
     * 添加文本碎片到 Session
     *
     * @param text 内容
     * @param date 碎片时间（默认当前时间）
     */
    nonisolated func addTextFragment(
        _ text: String,
        date: Date = Date(),
        to session: DailySession,
        context: ModelContext
    ) {
        let fragment = RawFragment(
            content: text,
            timestamp: getTimestamp(for: date),
            type: .text
        )
        
        fragment.dailySession = session
        session.fragments.append(fragment)
        context.insert(fragment)
        
        // 持久化保存
        try? context.save()
    }
    
    /**
     * 添加图片碎片到 Session
     *
     * @param imageData 压缩后的图片数据
     * @param caption 可选的图片描述
     * @param date 碎片时间（默认当前时间）
     */
    nonisolated func addImageFragment(
        _ imageData: Data,
        caption: String = "",
        date: Date = Date(),
        to session: DailySession,
        context: ModelContext
    ) {
        let fragment = RawFragment(
            content: caption,
            imageData: imageData,
            timestamp: getTimestamp(for: date),
            type: .image
        )
        
        fragment.dailySession = session
        session.fragments.append(fragment)
        context.insert(fragment)
        
        // 持久化保存
        try? context.save()
    }
    
    /**
     * 添加待处理图片碎片（用于异步上传）
     *
     * @param imageData 初始图片数据（可能是缩略图或未完全压缩图）
     * @return 新创建的碎片 ID
     */
    nonisolated func addPendingImageFragment(
        _ imageData: Data,
        caption: String = "",
        date: Date = Date(),
        to session: DailySession,
        context: ModelContext
    ) -> UUID {
        let id = UUID()
        let fragment = RawFragment(
            id: id,
            content: caption,
            imageData: imageData,
            timestamp: getTimestamp(for: date),
            type: .image,
            isProcessing: true
        )
        
        fragment.dailySession = session
        session.fragments.append(fragment)
        context.insert(fragment)
        
        try? context.save()
        return id
    }
    
    /**
     * 完成图片处理
     */
    nonisolated func completeImageFragment(
        id: UUID,
        finalData: Data,
        context: ModelContext
    ) {
        let descriptor = FetchDescriptor<RawFragment>(
            predicate: #Predicate { $0.id == id }
        )
        
        if let fragment = try? context.fetch(descriptor).first {
            fragment.imageData = finalData
            fragment.isProcessing = false
            try? context.save()
        }
    }
    
    /**
     * 更新碎片内容（用于编辑）
     */
    nonisolated func updateFragment(_ fragment: RawFragment, newContent: String) {
        fragment.content = newContent
        fragment.editedAt = getCurrentTimestamp()
    }
    
    /**
     * 删除碎片
     */
    nonisolated func deleteFragment(_ fragment: RawFragment, context: ModelContext) {
        context.delete(fragment)
    }
    
    // MARK: - Helper Methods
    
    /**
     * 获取当前日期字符串（YYYY-MM-DD）
     */
    nonisolated private func getCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }
    
    /**
     * 获取指定日期的 Unix 时间戳（毫秒）
     */
    nonisolated private func getTimestamp(for date: Date) -> Int64 {
        return Int64(date.timeIntervalSince1970 * 1000)
    }
    
    /**
     * 获取当前时间戳（Unix 毫秒）
     */
    nonisolated private func getCurrentTimestamp() -> Int64 {
        return getTimestamp(for: Date())
    }
}
