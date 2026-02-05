//
//  MemoryService.swift
//  Wing
//
//  Created on 2026-02-05.
//

import Foundation
import SwiftData

/**
 * 记忆服务 Actor
 * 负责与 AI 交互以提取记忆，并管理长期记忆的存储与去重。
 * 使用独立 Actor 与 ModelContext 确保后台处理不阻塞主线程。
 */
actor MemoryService {
    private let modelContext: ModelContext
    
    init(container: ModelContainer) {
        self.modelContext = ModelContext(container)
        // 禁用自动保存，手动控制事务
        self.modelContext.autosaveEnabled = false
    }
    
    // MARK: - Public API
    
    /**
     * 为指定日记条目提取记忆
     *
     * - Parameter entryId: 日记条目的 UUID
     */
    func extractMemories(for entryId: UUID) async throws {
        // 1. 在当前 Context 中获取日记条目
        let entryDescriptor = FetchDescriptor<WingEntry>(predicate: #Predicate { $0.id == entryId })
        guard let entry = try modelContext.fetch(entryDescriptor).first else {
            print("MemoryService: Entry not found for id \(entryId)")
            return
        }
        
        // 2. 获取 AI 配置
        // SettingsManager.shared 是 MainActor，需要 await
        guard let config = await SettingsManager.shared.getAIConfig() else {
            throw AIError.missingAPIKey
        }
        
        print("MemoryService: Extraction started for entry \(entry.title)")
        
        // 3. 调用 AI 提取
        // 提取 Markdown 正文（通常这是最有价值的部分）
        let contentToAnalyze = entry.markdownContent
        guard !contentToAnalyze.isEmpty else { return }
        
        // 获取语言设置
        // SettingsManager.shared 是 MainActor，需要 await
        let language = await SettingsManager.shared.getJournalLanguage()
        
        let result = try await AIService.shared.extractMemories(content: contentToAnalyze, config: config, language: language)
        
        // 4. 处理并存储结果
        try processSemantic(result.semantic, sourceId: entryId)
        try processEpisodic(result.episodic, sourceId: entryId, defaultDate: entry.createdAt)
        try processProcedural(result.procedural, sourceId: entryId)
        
        // 5. 提交事务
        try modelContext.save()
        print("MemoryService: Extraction completed and saved.")
    }
    
    // Internal for testing
    func save() throws {
        try modelContext.save()
    }
    
    // MARK: - Internal Processing
    
    // Internal for testing
    func processSemantic(_ items: [SemanticMemoryItem], sourceId: UUID) throws {
        let now = Int64((Date().timeIntervalSince1970 * 1000.0).rounded())
        
        for item in items {
            // 去重逻辑：查找相同 Key 的记忆
            let key = item.key
            let descriptor = FetchDescriptor<SemanticMemory>(predicate: #Predicate { $0.key == key })
            let existingMemories = try modelContext.fetch(descriptor)
            
            if let existing = existingMemories.first {
                // 已存在：如果值非常相似，则增加置信度或忽略
                // 暂时策略：保留旧值，更新 updatedAt 和来源
                if !existing.sourceEntryIds.contains(sourceId) {
                    existing.sourceEntryIds.append(sourceId)
                }
                existing.updatedAt = now
            } else {
                // 新记忆
                let newMemory = SemanticMemory(
                    key: item.key,
                    value: item.value,
                    confidence: item.confidence,
                    sourceEntryIds: [sourceId],
                    createdAt: now,
                    updatedAt: now
                )
                modelContext.insert(newMemory)
            }
        }
    }
    
    // Internal for testing
    func processEpisodic(_ items: [EpisodicMemoryItem], sourceId: UUID, defaultDate: Int64) throws {
        let now = Int64((Date().timeIntervalSince1970 * 1000.0).rounded())
        let defaultDateString = Date(timeIntervalSince1970: TimeInterval(defaultDate) / 1000)
            .formatted(.iso8601.year().month().day().dateSeparator(.dash))
        
        for item in items {
            // 规范化日期：AI 可能返回 "Today" 或 YYYY-MM-DD
            // 如果解析失败，使用日记创建日期
            let dateStr = item.date.contains("-") ? item.date : defaultDateString
            
            // 去重逻辑：检查同一天是否有极其相似的事件
            let descriptor = FetchDescriptor<EpisodicMemory>(predicate: #Predicate { $0.date == dateStr })
            let existingMemories = try modelContext.fetch(descriptor)
            
            // 简单的文本包含检查
            let isDuplicate = existingMemories.contains { memory in
                return memory.event.localizedCaseInsensitiveContains(item.event) || item.event.localizedCaseInsensitiveContains(memory.event)
            }
            
            if !isDuplicate {
                let newMemory = EpisodicMemory(
                    event: item.event,
                    emotion: item.emotion,
                    date: dateStr,
                    context: item.context,
                    sourceEntryId: sourceId,
                    createdAt: now
                )
                modelContext.insert(newMemory)
            }
        }
    }
    
    // Internal for testing
    func processProcedural(_ items: [ProceduralMemoryItem], sourceId: UUID) throws {
        let now = Int64((Date().timeIntervalSince1970 * 1000.0).rounded())
        
        for item in items {
            // 去重逻辑：检查 Pattern
            let pattern = item.pattern
            let descriptor = FetchDescriptor<ProceduralMemory>(predicate: #Predicate { $0.pattern == pattern })
            let existingMemories = try modelContext.fetch(descriptor)
            
            if let existing = existingMemories.first {
                // 已存在：增加频率
                existing.frequency += 1
                existing.updatedAt = now
                if !existing.sourceEntryIds.contains(sourceId) {
                    existing.sourceEntryIds.append(sourceId)
                }
            } else {
                // 新记忆
                let newMemory = ProceduralMemory(
                    pattern: item.pattern,
                    preference: item.preference,
                    trigger: item.trigger,
                    frequency: 1,
                    sourceEntryIds: [sourceId],
                    createdAt: now,
                    updatedAt: now
                )
                modelContext.insert(newMemory)
            }
        }
    }
    // MARK: - Merge & Consolidation
    
    /**
     * 查找合并候选组
     *
     * - Parameter type: 记忆类型
     * - Returns: 候选组列表
     */
    func findMergeCandidates(type: MemoryType) throws -> [MergeCandidateGroup] {
        var groups: [MergeCandidateGroup] = []
        
        switch type {
        case .semantic:
            // 语义记忆：按 Key 分组，找出 Key 相同但 ID 不同的
            // 注意：fetch all 可能有性能问题，但在个人日记场景下数量可控
            let descriptor = FetchDescriptor<SemanticMemory>(sortBy: [SortDescriptor(\.key)])
            let allMemories = try modelContext.fetch(descriptor)
            
            let grouped = Dictionary(grouping: allMemories, by: { $0.key })
            for (key, memories) in grouped where memories.count > 1 {
                groups.append(MergeCandidateGroup(
                    type: .semantic,
                    groupKey: key,
                    memoryIds: memories.map { $0.id },
                    suggestedContent: memories.max(by: { $0.confidence < $1.confidence })?.value
                ))
            }
            
        case .episodic:
            // 情景记忆：按 Date 分组，组内比较文本相似度
            let descriptor = FetchDescriptor<EpisodicMemory>(sortBy: [SortDescriptor(\.date)])
            let allMemories = try modelContext.fetch(descriptor)
            
            let groupedByDate = Dictionary(grouping: allMemories, by: { $0.date })
            
            for (date, dateMemories) in groupedByDate {
                // 简单的 n^2 比较，找出高相似度群组
                // 为简化实现，这里只找两两相似的，或者使用聚类
                // 简化策略：如果有两个事件相似度 > 0.6，就分为一组
                
                var visited = Set<UUID>()
                
                for i in 0..<dateMemories.count {
                    let m1 = dateMemories[i]
                    if visited.contains(m1.id) { continue }
                    
                    var currentGroup = [m1]
                    visited.insert(m1.id)
                    
                    for j in (i+1)..<dateMemories.count {
                        let m2 = dateMemories[j]
                        if visited.contains(m2.id) { continue }
                        
                        if m1.event.similarity(to: m2.event) > 0.45 {
                            currentGroup.append(m2)
                            visited.insert(m2.id)
                        }
                    }
                    
                    if currentGroup.count > 1 {
                        groups.append(MergeCandidateGroup(
                            type: .episodic,
                            groupKey: date,
                            memoryIds: currentGroup.map { $0.id },
                            suggestedContent: currentGroup.max(by: { $0.event.count < $1.event.count })?.event
                        ))
                    }
                }
            }
            
        case .procedural:
            // 程序性记忆：比较 Pattern 相似度
            let descriptor = FetchDescriptor<ProceduralMemory>()
            let allMemories = try modelContext.fetch(descriptor)
            
            var visited = Set<UUID>()
            
            for i in 0..<allMemories.count {
                let m1 = allMemories[i]
                if visited.contains(m1.id) { continue }
                
                var currentGroup = [m1]
                visited.insert(m1.id)
                
                for j in (i+1)..<allMemories.count {
                    let m2 = allMemories[j]
                    if visited.contains(m2.id) { continue }
                    
                    if m1.pattern.similarity(to: m2.pattern) > 0.55 {
                        currentGroup.append(m2)
                        visited.insert(m2.id)
                    }
                }
                
                if currentGroup.count > 1 {
                    groups.append(MergeCandidateGroup(
                        type: .procedural,
                        groupKey: m1.pattern, // 使用第一个作为 key pattern
                        memoryIds: currentGroup.map { $0.id },
                        suggestedContent: currentGroup.max(by: { $0.frequency < $1.frequency })?.pattern
                    ))
                }
            }
        }
        
        return groups
    }
    
    /**
     * 执行合并
     *
     * - Parameters:
     *   - keepingId: 保留的记忆 ID
     *   - discardingIds: 需合并删除的记忆 ID 列表
     *   - type: 记忆类型
     */
    func mergeMemories(keepingId: UUID, discardingIds: [UUID], type: MemoryType) throws {
        switch type {
        case .semantic:
            let keepDesc = FetchDescriptor<SemanticMemory>(predicate: #Predicate { $0.id == keepingId })
            guard let keeper = try modelContext.fetch(keepDesc).first else { return }
            
            // 收集所有被删除项的 sourceEntryIds
            var sourcesToMerge = Set(keeper.sourceEntryIds)
            
            for discardId in discardingIds {
                let desc = FetchDescriptor<SemanticMemory>(predicate: #Predicate { $0.id == discardId })
                if let item = try modelContext.fetch(desc).first {
                    sourcesToMerge.formUnion(item.sourceEntryIds)
                    modelContext.delete(item)
                }
            }
            
            keeper.sourceEntryIds = Array(sourcesToMerge)
            keeper.updatedAt = Int64((Date().timeIntervalSince1970 * 1000.0).rounded())
            
        case .episodic:
            // 情景记忆不存储 sourceEntryIds 列表（只有单 sourceEntryId），这里可能需要逻辑
            // 如果合并，我们只能保留一个主 sourceEntryId，或者 episodicMemory 应该支持多个 sources？
            // 目前定义：EpisodicMemory check WingModels.swift: sourceEntryId: UUID (Single)
            // 所以合并时，我们丢失了其他 source 引用，这在 Episodic 场景下通常是可以接受的（因为是同一件事）
            // 或者，我们可以修改 Model 支持 [UUID]
            // FOR NOW: 仅保留 keeper 的 sourceEntryId.
            
            for discardId in discardingIds {
                let desc = FetchDescriptor<EpisodicMemory>(predicate: #Predicate { $0.id == discardId })
                if let item = try modelContext.fetch(desc).first {
                    modelContext.delete(item)
                }
            }
            
        case .procedural:
            let keepDesc = FetchDescriptor<ProceduralMemory>(predicate: #Predicate { $0.id == keepingId })
            guard let keeper = try modelContext.fetch(keepDesc).first else { return }
            
            var sourcesToMerge = Set(keeper.sourceEntryIds)
            var totalFreq = keeper.frequency
            
            for discardId in discardingIds {
                let desc = FetchDescriptor<ProceduralMemory>(predicate: #Predicate { $0.id == discardId })
                if let item = try modelContext.fetch(desc).first {
                    sourcesToMerge.formUnion(item.sourceEntryIds)
                    totalFreq += item.frequency
                    modelContext.delete(item)
                }
            }
            
            keeper.sourceEntryIds = Array(sourcesToMerge)
            keeper.frequency = totalFreq
            keeper.updatedAt = Int64((Date().timeIntervalSince1970 * 1000.0).rounded())
        }
        
        try modelContext.save()
    }
}

// Extension removed to avoid concurrency warnings

