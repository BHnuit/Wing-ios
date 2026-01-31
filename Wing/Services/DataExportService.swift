//
//  DataExportService.swift
//  Wing
//
//  Created on 2026-01-31.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Export Models

/**
 * 完整数据导出模型
 * 包含所有 DailySession、WingEntry、RawFragment 等关联数据
 */
struct WingExportData: Codable {
    let version: String
    let exportedAt: String
    let sessions: [DailySessionExport]
    
    init(sessions: [DailySessionExport]) {
        self.version = "1.1"
        self.exportedAt = ISO8601DateFormatter().string(from: Date())
        self.sessions = sessions
    }
}

struct DailySessionExport: Codable {
    let id: UUID
    let date: String
    let status: String
    let fragments: [FragmentExport]
    let entries: [EntryExport]
    
    init(from session: DailySession, entries: [WingEntry]) {
        self.id = session.id
        self.date = session.date
        self.status = session.status.rawValue
        self.fragments = session.fragments.map { FragmentExport(from: $0) }
        self.entries = entries.map { EntryExport(from: $0) }
    }
    
    // For orphaned entries with no real session
    init(date: String, entries: [WingEntry]) {
        self.id = UUID()
        self.date = date
        self.status = "COMPLETED" // Assumed
        self.fragments = []
        self.entries = entries.map { EntryExport(from: $0) }
    }
}

struct FragmentExport: Codable {
    let id: UUID
    let content: String
    let type: String
    let timestamp: Int64
    let imageDataBase64: String?
    
    init(from fragment: RawFragment) {
        self.id = fragment.id
        self.content = fragment.content
        self.type = fragment.type.rawValue
        self.timestamp = fragment.timestamp
        if let data = fragment.imageData {
            self.imageDataBase64 = data.base64EncodedString()
        } else {
            self.imageDataBase64 = nil
        }
    }
}

struct EntryExport: Codable {
    let id: UUID
    let title: String
    let summary: String
    let mood: String
    let content: String
    let insights: String
    let todos: [WingTodo]
    let createdAt: Int64
    let imagesBase64: [String: String]
    
    init(from entry: WingEntry) {
        self.id = entry.id
        self.title = entry.title
        self.summary = entry.summary
        self.mood = entry.mood
        self.content = entry.markdownContent
        self.insights = entry.aiInsights
        self.todos = entry.todos
        self.createdAt = entry.createdAt
        
        var imagesMap: [String: String] = [:]
        for (id, data) in entry.images {
            imagesMap[id.uuidString] = data.base64EncodedString()
        }
        self.imagesBase64 = imagesMap
    }
}

// MARK: - Data Export Service

/**
 * 数据导出服务
 * 提供 JSON（全量备份）和 Markdown（可读导出）两种格式
 */
@MainActor
final class DataExportService {
    static let shared = DataExportService()
    
    private init() {}
    
    /// 导出全量 JSON 数据
    func exportJSON(context: ModelContext) async throws -> URL {
        // 1. 获取所有 Session
        let sessionDescriptor = FetchDescriptor<DailySession>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let sessions = try context.fetch(sessionDescriptor)
        
        // 2. 获取所有 Entry
        let entryDescriptor = FetchDescriptor<WingEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let allEntries = try context.fetch(entryDescriptor)
        
        // 3. 将 Entry 按 Session ID 分组
        var sessionEntriesMap: [UUID: [WingEntry]] = [:]
        var orphanedEntries: [WingEntry] = []
        
        for entry in allEntries {
            if let session = entry.dailySession {
                sessionEntriesMap[session.id, default: []].append(entry)
            } else {
                orphanedEntries.append(entry)
            }
        }
        
        // 4. 构建 Export 对象
        var exportSessions: [DailySessionExport] = []
        
        // 4.1 处理已存在的 Session
        for session in sessions {
            let entries = sessionEntriesMap[session.id] ?? []
            exportSessions.append(DailySessionExport(from: session, entries: entries))
        }
        
        // 4.2 处理孤儿 Entry (按日期分组创建虚拟 Session)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let orphanedByDate = Dictionary(grouping: orphanedEntries) { entry in
            return dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(entry.createdAt) / 1000))
        }
        
        for (date, entries) in orphanedByDate {
            // 检查该日期是否已经存在于 exportSessions 中 (通常如果不匹配 ID，说明是不同的 Session，或者是数据错乱)
            // 这里我们选择简单策略：如果该日期没有对应的真实 Session，则创建虚拟 Session
            if !exportSessions.contains(where: { $0.date == date }) {
                exportSessions.append(DailySessionExport(date: date, entries: entries))
            } else {
                // 如果已存在同日期的真实 Session，但这些 Entry 没关联上，我们应该把它们加进去吗？
                // 逻辑上应该是加进去，但为了 ID 一致性，我们可能需要找到那个 SessionExport 并追加
                // 但由于 DailySessionExport 是 struct，修改比较麻烦。
                // 鉴于这是备份，我们创建一个新的 "Appendix" Session 或者直接作为独立项
                // 为了简单且保存数据，我们创建一个新的条目，可能会有日期重复，但在 JSON 里是允许的
                exportSessions.append(DailySessionExport(date: date, entries: entries))
            }
        }
        
        // 排序：按日期倒序
        exportSessions.sort { $0.date > $1.date }
        
        let exportData = WingExportData(sessions: exportSessions)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(exportData)
        
        let fileName = "wing_backup_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).json"
        return try saveToTemporaryFile(data: data, fileName: fileName)
    }
    
    /// 导出单篇日记 Markdown
    func exportMarkdown(for entry: WingEntry) async throws -> URL {
        var dateStr = ""
        if let session = entry.dailySession {
            dateStr = session.date
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateStr = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(entry.createdAt) / 1000))
        }
        
        var mdContent = "# \(dateStr) | \(entry.title)\n\n"
        mdContent += "**心情**: \(entry.mood) | **摘要**: \(entry.summary)\n\n"
        mdContent += "\(entry.markdownContent)\n\n"
        
        if !entry.aiInsights.isEmpty {
            mdContent += "### 🔮 洞察\n"
            mdContent += "\(entry.aiInsights)\n\n"
        }
        
        if !entry.todos.isEmpty {
            mdContent += "### ✅ 待办\n"
            for todo in entry.todos {
                let mark = todo.completed ? "[x]" : "[ ]"
                mdContent += "- \(mark) \(todo.title)\n"
            }
            mdContent += "\n"
        }
        
        // 导出时间
        mdContent += "---\n"
        mdContent += "导出时间: \(Date().formatted())\n"
        
        let data = mdContent.data(using: .utf8) ?? Data()
        // 使用 entry ID 避免文件名冲突
        let fileName = "wing_diary_\(dateStr)_\(entry.id.uuidString.prefix(4)).md"
        return try saveToTemporaryFile(data: data, fileName: fileName)
    }
    
    enum ExportError: Error {
        case noEntry
    }
    
    private func saveToTemporaryFile(data: Data, fileName: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }
}
