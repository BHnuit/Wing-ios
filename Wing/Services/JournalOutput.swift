//
//  JournalOutput.swift
//  Wing
//
//  Created on 2026-01-29.
//

import Foundation

/**
 * AI 日记合成输出结构
 * 遵循 Sendable 协议以支持跨 actor 边界传递
 * 显式实现 Codable 以避免 Swift 6 并发安全警告
 */
struct JournalOutput: Sendable {
    /// 日记标题
    let title: String
    
    /// 一句话摘要
    let summary: String
    
    /// 心情 Emoji
    let mood: String
    
    /// Markdown 格式的正文
    let content: String
    
    /// AI 洞察（猫头鹰的评论）
    let insights: String
    
    /// 原始 JSON 字符串（用于调试）
    let rawJSON: String?
    
    nonisolated init(
        title: String,
        summary: String,
        mood: String,
        content: String,
        insights: String,
        rawJSON: String? = nil
    ) {
        self.title = title
        self.summary = summary
        self.mood = mood
        self.content = content
        self.insights = insights
        self.rawJSON = rawJSON
    }
}

// MARK: - Codable

extension JournalOutput: Codable {
    enum CodingKeys: String, CodingKey {
        case title, summary, mood, content, insights, rawJSON
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decode(String.self, forKey: .summary)
        mood = try container.decode(String.self, forKey: .mood)
        content = try container.decode(String.self, forKey: .content)
        insights = try container.decode(String.self, forKey: .insights)
        rawJSON = try container.decodeIfPresent(String.self, forKey: .rawJSON)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(summary, forKey: .summary)
        try container.encode(mood, forKey: .mood)
        try container.encode(content, forKey: .content)
        try container.encode(insights, forKey: .insights)
        try container.encodeIfPresent(rawJSON, forKey: .rawJSON)
    }
}

// MARK: - Fallback

extension JournalOutput {
    /// 创建 Fallback 输出（解析失败时使用）
    nonisolated static func fallback(rawContent: String) -> JournalOutput {
        return JournalOutput(
            title: "无题日记",
            summary: "今日的记录",
            mood: "📝",
            content: rawContent,
            insights: "今天的想法已被记录下来。",
            rawJSON: nil
        )
    }
    
    /// 清理内容格式（修复换行符转义问题）
    nonisolated func sanitized() -> JournalOutput {
        // 修复可能的双重转义换行符 (\\n -> \n) 和异常字符 (/n -> \n)
        let cleanContent = content
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "/n/n", with: "\n\n") // 修复特定异常标识符
            .replacingOccurrences(of: "/n", with: "\n")
        
        let cleanInsights = insights
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "/n/n", with: "\n\n")
            .replacingOccurrences(of: "/n", with: "\n")
        
        return JournalOutput(
            title: title,
            summary: summary,
            mood: mood,
            content: cleanContent,
            insights: cleanInsights,
            rawJSON: rawJSON
        )
    }
}
