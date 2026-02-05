//
//  MemoryServiceTests.swift
//  WingTests
//
//  Created on 2026-02-05.
//

import Testing
import SwiftData
import Foundation
@testable import Wing

@Suite("Memory Service Tests")
struct MemoryServiceTests {
    
    @MainActor
    static func createContainer() throws -> ModelContainer {
        let schema = Schema([
            SemanticMemory.self,
            EpisodicMemory.self,
            ProceduralMemory.self,
            WingEntry.self,
            DailySession.self,
            RawFragment.self,
            AppSettings.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }
    
    @Test("Semantic Memory Deduplication")
    func testSemanticDedup() async throws {
        let container = try await Self.createContainer()
        let service = MemoryService(container: container)
        let sourceId = UUID()
        
        let item = SemanticMemoryItem(key: "user_name", value: "Hans", confidence: 0.9)
        
        // 1. Initial Insert
        try await service.processSemantic([item], sourceId: sourceId)
        try await service.save() // Commit changes
        
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SemanticMemory>()
        let memories = try context.fetch(descriptor)
        
        #expect(memories.count == 1)
        #expect(memories.first?.key == "user_name")
        #expect(memories.first?.value == "Hans")
        
        // 2. Duplicate Insert (same key)
        let item2 = SemanticMemoryItem(key: "user_name", value: "Hans New", confidence: 0.95)
        try await service.processSemantic([item2], sourceId: sourceId)
        try await service.save() // Commit changes
        
        let memories2 = try context.fetch(descriptor)
        #expect(memories2.count == 1) // Should still be 1
        #expect(memories2.first?.value == "Hans") // Should keep old value per V1 logic
    }
    
    @Test("Episodic Memory Deduplication")
    func testEpisodicDedup() async throws {
        let container = try await Self.createContainer()
        let service = MemoryService(container: container)
        let sourceId = UUID()
        let now = Date().millisecondsSince1970
        
        let item = EpisodicMemoryItem(event: "Went to the park", date: "2026-02-05", emotion: "Happy", context: nil)
        
        // 1. Initial Insert
        try await service.processEpisodic([item], sourceId: sourceId, defaultDate: now)
        try await service.save()
        
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<EpisodicMemory>()
        let memories = try context.fetch(descriptor)
        
        #expect(memories.count == 1)
        
        // 2. Duplicate Insert (Similar event, same date)
        let item2 = EpisodicMemoryItem(event: "I went to the park", date: "2026-02-05", emotion: nil, context: nil)
        try await service.processEpisodic([item2], sourceId: sourceId, defaultDate: now)
        try await service.save()
        
        let memories2 = try context.fetch(descriptor)
        #expect(memories2.count == 1)
        
        // 3. Different Date Insert
        let item3 = EpisodicMemoryItem(event: "Went to the park", date: "2026-02-06", emotion: nil, context: nil)
        try await service.processEpisodic([item3], sourceId: sourceId, defaultDate: now)
        try await service.save()
        
        let memories3 = try context.fetch(descriptor)
        #expect(memories3.count == 2)
    }
    
    @Test("Procedural Memory Frequency")
    func testProceduralFrequency() async throws {
        let container = try await Self.createContainer()
        let service = MemoryService(container: container)
        let sourceId = UUID()
        
        let item = ProceduralMemoryItem(pattern: "Late night writing", preference: "Quiet", trigger: nil)
        
        // 1. Initial Insert
        try await service.processProcedural([item], sourceId: sourceId)
        try await service.save()
        
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ProceduralMemory>()
        let memories = try context.fetch(descriptor)
        
        #expect(memories.count == 1)
        #expect(memories.first?.frequency == 1)
        
        // 2. Recurrence
        try await service.processProcedural([item], sourceId: sourceId)
        try await service.save()
        
        let memories2 = try context.fetch(descriptor)
        #expect(memories2.count == 1)
        #expect(memories2.first?.frequency == 2)
    }
}

fileprivate extension Date {
    var millisecondsSince1970: Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
}
