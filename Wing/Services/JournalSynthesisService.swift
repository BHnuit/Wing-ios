//
//  JournalSynthesisService.swift
//  Wing
//
//  Created on 2026-01-29.
//

import Foundation
import SwiftData

/**
 * 日记合成服务
 *
 * 使用 @MainActor 以确保与 SwiftData 的 ModelContext 兼容
 *
 * 职责：
 * 1. 编排完整的日记生成流程
 * 2. 从 DailySession 获取碎片
 * 3. 调用 AIService 生成日记
 * 4. 创建 WingEntry 并关联到 Session
 * 5. 更新 Session 状态
 */
@MainActor
final class JournalSynthesisService {
    
    static let shared = JournalSynthesisService()
    
    private init() {}
    
    /**
     * 合成日记
     *
     * @param session 当日的 DailySession
     * @param config AI 配置
     * @param context SwiftData ModelContext
     * @param progressCallback 进度回调（用于 UI 更新）
     * @return 生成的 WingEntry ID
     */
    func synthesize(
        session: DailySession,
        config: AIConfig,
        context: ModelContext,
        progressCallback: @escaping (SynthesisProgress) -> Void
    ) async throws -> UUID {
        // 1. 验证碎片
        guard !session.fragments.isEmpty else {
            throw SynthesisError.noFragments
        }
        
        // 2. 更新状态：开始合成
        progressCallback(.started)
        
        session.status = .processing
        let startTimestamp = Int64(Date().timeIntervalSince1970 * 1000)
        session.gatherStartedAt.append(startTimestamp)
        
        do {
            // 3. 调用 AI 服务
            progressCallback(.generating)
            
            let output = try await AIService.shared.synthesizeJournal(
                fragments: session.fragments,
                config: config
            )
            
            // 4. 创建 WingEntry
            progressCallback(.saving)
            
            let entryId = UUID()
            let entry = WingEntry(
                id: entryId,
                title: output.title,
                summary: output.summary,
                mood: output.mood,
                markdownContent: output.content,
                aiInsights: output.insights,
                createdAt: Int64(Date().timeIntervalSince1970 * 1000),
                generatedAt: Int64(Date().timeIntervalSince1970 * 1000)
            )
            
            // 4.1 复制碎片中的图片到 Entry
            var entryImages: [UUID: Data] = [:]
            for fragment in session.fragments {
                if fragment.type == .image, let imageData = fragment.imageData {
                    entryImages[fragment.id] = imageData
                }
            }
            entry.images = entryImages
            
            // 5. 关联到 Session
            entry.dailySession = session
            session.finalEntry = entry
            session.finalEntryId = entryId
            session.status = .completed
            
            // 6. 记录完成信息
            let completion = GatherCompletion(
                completedAt: Int64(Date().timeIntervalSince1970 * 1000),
                entryId: entryId,
                title: entry.title
            )
            session.gatherCompletions.append(completion)
            
            // 7. 保存到数据库
            context.insert(entry)
            try context.save()
            
            // 8. 完成
            progressCallback(.completed(entryId: entryId))
            
            return entryId
            
        } catch {
            // 失败时恢复状态
            session.status = .recording
            progressCallback(.failed(error: error))
            throw error
        }
    }
}

// MARK: - Supporting Types

/**
 * 合成进度枚举
 */
enum SynthesisProgress: Sendable {
    case started
    case generating
    case saving
    case completed(entryId: UUID)
    case failed(error: Error)
    
    var message: String {
        switch self {
        case .started:
            return "正在收拢今日羽毛..."
        case .generating:
            return "正在编织日记..."
        case .saving:
            return "正在洞察感受..."
        case .completed:
            return "完成 ✨"
        case .failed(let error):
            return "生成失败: \(error.localizedDescription)"
        }
    }
}

/**
 * 合成错误枚举
 */
enum SynthesisError: Error, LocalizedError, Sendable {
    case noFragments
    case configurationMissing
    
    var errorDescription: String? {
        switch self {
        case .noFragments:
            return "没有可用的碎片记录"
        case .configurationMissing:
            return "缺少 AI 配置，请在设置中配置 API Key"
        }
    }
}
