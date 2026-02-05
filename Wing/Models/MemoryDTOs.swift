//
//  MemoryDTOs.swift
//  Wing
//
//  Created on 2026-02-05.
//

import Foundation

// MARK: - Merge Candidates

/**
 * 记忆合并候选组
 * 包含一组被认为相似的记忆条目
 */
struct MergeCandidateGroup: Identifiable, Hashable, Sendable {
    let id: UUID = UUID()
    let type: MemoryType
    /// 这一组中主要的 Key (Semantic) 或 Pattern (Procedural) 或 Date (Episodic)
    let groupKey: String
    /// 包含的记忆 ID 列表
    let memoryIds: [UUID]
    /// 建议保留的记忆内容（可选，若为 nil 则需用户选择）
    let suggestedContent: String?
}

// MARK: - Memory Extraction Results
struct MemoryExtractionResult: Codable, Sendable {
    var semantic: [SemanticMemoryItem]
    var episodic: [EpisodicMemoryItem]
    var procedural: [ProceduralMemoryItem]
    
    enum CodingKeys: String, CodingKey {
        case semantic, episodic, procedural
    }
    
    nonisolated init(semantic: [SemanticMemoryItem], episodic: [EpisodicMemoryItem], procedural: [ProceduralMemoryItem]) {
        self.semantic = semantic
        self.episodic = episodic
        self.procedural = procedural
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.semantic = try container.decode([SemanticMemoryItem].self, forKey: .semantic)
        self.episodic = try container.decode([EpisodicMemoryItem].self, forKey: .episodic)
        self.procedural = try container.decode([ProceduralMemoryItem].self, forKey: .procedural)
    }
}

struct SemanticMemoryItem: Codable, Sendable {
    var key: String
    var value: String
    var confidence: Double
}

struct EpisodicMemoryItem: Codable, Sendable {
    var event: String
    var date: String
    var emotion: String?
    var context: String?
}

struct ProceduralMemoryItem: Codable, Sendable {
    var pattern: String
    var preference: String
    var trigger: String?
}
