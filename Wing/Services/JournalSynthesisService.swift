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
     * @param journalLanguage 日记语言设置
     * @param context SwiftData ModelContext
     * @param progressCallback 进度回调（用于 UI 更新）
     * @return 生成的 WingEntry ID
     */
    func synthesize(
        session: DailySession,
        config: AIConfig,
        journalLanguage: JournalLanguage = .auto,
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
            // 2.1 检索相关记忆 (RAG)
            var memories: [String] = []
            let isRAGEnabled = SettingsManager.shared.appSettings?.memoryRetrievalEnabled ?? false
            
            if isRAGEnabled {
                do {
                    let memoryService = MemoryService(container: context.container)
                    let combinedContext = session.fragments.map { $0.content }.joined(separator: "\n")
                    memories = try await memoryService.retrieveRelevantMemories(for: combinedContext)
                } catch {
                    // RAG 检索失败不应阻断日记生成
                    print("JournalSynthesisService: Memory retrieval failed, continuing without RAG: \(error)")
                }
            }
            
            // 3. 调用 AI 服务
            progressCallback(.generating)
            
            let output = try await AIService.shared.synthesizeJournal(
                fragments: session.fragments,
                memories: memories,
                config: config,
                journalLanguage: journalLanguage,
                writingStyle: SettingsManager.shared.appSettings?.writingStyle ?? .prose,
                writingStylePrompt: SettingsManager.shared.appSettings?.writingStylePrompt,
                titleStyle: SettingsManager.shared.appSettings?.titleStyle ?? .abstract,
                titleStylePrompt: SettingsManager.shared.appSettings?.titleStylePrompt,
                insightPrompt: SettingsManager.shared.appSettings?.insightPrompt
            )
            
            // 4. 创建 WingEntry
            progressCallback(.saving)
            
            // Calculate createdAt based on session date (23:59:59)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let sessionDate = formatter.date(from: session.date) ?? Date()
            
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: sessionDate)
            components.hour = 23
            components.minute = 59
            components.second = 59
            let createdAtDate = calendar.date(from: components) ?? Date()

            let entryId = UUID()
            let entry = WingEntry(
                id: entryId,
                title: output.title,
                summary: output.summary,
                mood: output.mood,
                markdownContent: output.content,
                aiInsights: output.insights,
                createdAt: Int64(createdAtDate.timeIntervalSince1970 * 1000),
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
            
            // 5. 清理旧日记（重新生成场景）
            //    必须在设置新关系之前删除旧 Entry，否则 SwiftData 更新反向关系时
            //    会惰性加载旧对象导致 "Never access a full future backing data" Crash
            if let oldEntryId = session.finalEntryId {
                let descriptor = FetchDescriptor<WingEntry>(
                    predicate: #Predicate { $0.id == oldEntryId }
                )
                if let oldEntry = try? context.fetch(descriptor).first {
                    context.delete(oldEntry)
                }
                session.finalEntryId = nil
                try context.save()
            }
            
            // 6. 插入新 Entry 并建立关联
            context.insert(entry)
            session.finalEntry = entry   // SwiftData 自动维护 entry.dailySession 反向关系
            session.finalEntryId = entryId
            session.status = .completed
            
            // 7. 记录完成信息
            let completion = GatherCompletion(
                completedAt: Int64(Date().timeIntervalSince1970 * 1000),
                entryId: entryId,
                title: entry.title
            )
            session.gatherCompletions.append(completion)
            
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
        localizedMessage
    }
    
    
    var localizedMessage: String {
        switch self {
        case .started:
            return L("synthesis.started")
        case .generating:
            return L("synthesis.generating")
        case .saving:
            return L("synthesis.saving")
        case .completed:
            return L("synthesis.completed")
        case .failed(let error):
            return String(format: L("synthesis.failed"), error.localizedDescription)
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
            return L("synthesis.error.noFragments")
        case .configurationMissing:
            return L("synthesis.error.configMissing")
        }
    }
}
