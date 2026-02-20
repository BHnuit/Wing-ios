//
//  DataImportService.swift
//  Wing
//
//  Created on 2026-02-12.
//

import Foundation
import SwiftData
import SwiftUI

/**
 * 数据导入服务
 * 处理 JSON/ZIP 导入逻辑
 */
@MainActor
final class DataImportService {
    static let shared = DataImportService()
    
    private init() {}
    
    /// 同步扫描目录中的 JSON 文件（nonisolated 避免 async 上下文限制）
    nonisolated private static func scanJSONFiles(in url: URL) -> [URL] {
        var result: [URL] = []
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension.lowercased() == "json" {
                    result.append(fileURL)
                }
            }
        }
        return result
    }
    
    enum ImportError: Error, LocalizedError {
        case fileReadFailed
        case jsonDecodeFailed
        case invalidDataFormat
        case unknown
        
        var errorDescription: String? {
            switch self {
            case .fileReadFailed: return L("data.import.error.readFailed")
            case .jsonDecodeFailed: return L("data.import.error.jsonDecodeFailed")
            case .invalidDataFormat: return L("data.import.error.invalidFormat")
            case .unknown: return L("data.import.error.unknown")
            }
        }
    }
    
    // MARK: - Import Methods
    
    /// 从文件导入数据（合并模式）
    /// - Parameters:
    ///   - url: 文件 URL
    ///   - context: SwiftData 上下文
    func importJSON(from url: URL, context: ModelContext) async throws {
        let data = try await readFile(at: url)
        let exportData = try decodeData(data)
        try await importSessions(exportData.sessions, context: context, clearBeforeImport: false)
    }
    
    /// 从文件替换数据（清空后导入）
    func replaceData(from url: URL, context: ModelContext) async throws {
        let data = try await readFile(at: url)
        let exportData = try decodeData(data)
        try await importSessions(exportData.sessions, context: context, clearBeforeImport: true)
    }
    
    /// 从文件夹导入（扫描 JSON）
    func importFromFolder(url: URL, context: ModelContext, replace: Bool) async throws {
        // 1. 获取目录权限
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.fileReadFailed
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        // 2. 扫描 JSON 文件（同步操作，避免 async 上下文中调用 makeIterator）
        let jsonFiles = Self.scanJSONFiles(in: url)
        
        // 3. 逐个处理
        if replace {
            // 如果是替换模式，先清空一次
            try await clearAllData(context: context)
        }
        
        for file in jsonFiles {
            // 这里我们复用 importJSON 但不清除
            do {
                let data = try Data(contentsOf: file)
                // 尝试解码，可能是 WingExportData，也可能是单个 Entry？
                // 假设都是标准备份格式
                if let exportData = try? JSONDecoder().decode(WingExportData.self, from: data) {
                    try await importSessions(exportData.sessions, context: context, clearBeforeImport: false)
                }
            } catch {
                print("Failed to import file: \(file.lastPathComponent), error: \(error)")
                // 继续处理下一个文件
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func readFile(at url: URL) async throws -> Data {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        
        return try Data(contentsOf: url)
    }
    
    private func decodeData(_ data: Data) throws -> WingExportData {
        let decoder = JSONDecoder()
        return try decoder.decode(WingExportData.self, from: data)
    }
    
    private func clearAllData(context: ModelContext) async throws {
        // 删除所有主要数据
        try context.delete(model: DailySession.self)
        try context.delete(model: WingEntry.self)
        try context.delete(model: RawFragment.self)
        // 清空记忆数据
        try context.delete(model: SemanticMemory.self)
        try context.delete(model: EpisodicMemory.self)
        try context.delete(model: ProceduralMemory.self)
        try context.save()
    }
    
    private func importSessions(_ sessions: [DailySessionExport], context: ModelContext, clearBeforeImport: Bool) async throws {
        if clearBeforeImport {
            try await clearAllData(context: context)
        }
        
        // 缓存现有碎片 ID 以避免重复导入（仅在合并模式下）
        var existingFragmentIds: Set<UUID> = []
        
        if !clearBeforeImport {
            let fragDesc = FetchDescriptor<RawFragment>()
            let fragments = try context.fetch(fragDesc)
            existingFragmentIds = Set(fragments.map { $0.id })
        }
        
        for sessionExport in sessions {
            // 1. 创建或获取 Session
            let session: DailySession
            if !clearBeforeImport, let existing = try retrieveSession(date: sessionExport.date, context: context) {
                session = existing
            } else {
                session = DailySession(
                    id: sessionExport.id,
                    date: sessionExport.date,
                    status: SessionStatus(rawValue: sessionExport.status) ?? .completed
                )
                context.insert(session)
            }
            
            // 2. 导入 Fragments
            for fragExport in sessionExport.fragments {
                if !clearBeforeImport, existingFragmentIds.contains(fragExport.id) { continue }
                
                let imageData = fragExport.imageDataBase64.flatMap { Data(base64Encoded: $0) }
                let fragment = RawFragment(
                    id: fragExport.id,
                    content: fragExport.content,
                    imageData: imageData,
                    timestamp: fragExport.timestamp,
                    type: FragmentType(rawValue: fragExport.type) ?? .text
                )
                fragment.dailySession = session
                context.insert(fragment)
            }
            
            // 3. 导入 Entries
            for entryExport in sessionExport.entries {
                // 检查 Entry 是否存在
                if !clearBeforeImport {
                    let targetId = entryExport.id
                    let desc = FetchDescriptor<WingEntry>(predicate: #Predicate { $0.id == targetId })
                    if (try? context.fetch(desc).first) != nil { continue }
                }
                
                // 解码待办和图片
                var images: [UUID: Data] = [:]
                for (key, val) in entryExport.imagesBase64 {
                    if let uuid = UUID(uuidString: key), let data = Data(base64Encoded: val) {
                        images[uuid] = data
                    }
                }
                
                let entry = WingEntry(
                    id: entryExport.id,
                    title: entryExport.title,
                    summary: entryExport.summary,
                    mood: entryExport.mood,
                    markdownContent: entryExport.content,
                    aiInsights: entryExport.insights,
                    todos: entryExport.todos,
                    createdAt: entryExport.createdAt,
                    images: images
                )
                entry.dailySession = session
                context.insert(entry)
                
                // 更新 Session 的 finalEntry
                session.finalEntry = entry
                session.finalEntryId = entry.id
            }
        }
        
        try context.save()
    }
    
    private func retrieveSession(date: String, context: ModelContext) throws -> DailySession? {
        let descriptor = FetchDescriptor<DailySession>(predicate: #Predicate { $0.date == date })
        return try context.fetch(descriptor).first
    }
}
