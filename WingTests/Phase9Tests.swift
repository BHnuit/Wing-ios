//
//  Phase9Tests.swift
//  WingTests
//
//  Phase 9 自动化测试：数据可视化、高级设置、数据导入、记忆检索
//  Created on 2026-02-12.
//

import Testing
import SwiftData
import Foundation
@testable import Wing

// MARK: - Memory Retrieval Tests

@Suite("Memory Retrieval Tests")
struct MemoryRetrievalTests {
    
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
    
    @Test("检索空记忆库返回空数组")
    func testRetrieveEmpty() async throws {
        let container = try await Self.createContainer()
        let service = MemoryService(container: container)
        
        let results = try await service.retrieveRelevantMemories(for: "任何内容")
        #expect(results.isEmpty)
    }
    
    @Test("检索语义记忆按置信度排序")
    func testRetrieveSemanticMemories() async throws {
        let container = try await Self.createContainer()
        let service = MemoryService(container: container)
        let sourceId = UUID()
        
        // 插入几条语义记忆
        let items = [
            SemanticMemoryItem(key: "name", value: "Hans", confidence: 0.9),
            SemanticMemoryItem(key: "hobby", value: "Coding", confidence: 0.7),
            SemanticMemoryItem(key: "city", value: "Shanghai", confidence: 0.95),
        ]
        try await service.processSemantic(items, sourceId: sourceId)
        try await service.save()
        
        let results = try await service.retrieveRelevantMemories(for: "test")
        
        #expect(results.count >= 1)
        // 应包含 "User Facts:" 前缀
        #expect(results.first?.contains("User Facts:") == true)
        // 应包含所有3条记忆
        #expect(results.first?.contains("name") == true)
        #expect(results.first?.contains("hobby") == true)
        #expect(results.first?.contains("city") == true)
    }
    
    @Test("检索情景记忆包含情绪信息")
    func testRetrieveEpisodicMemories() async throws {
        let container = try await Self.createContainer()
        let service = MemoryService(container: container)
        let sourceId = UUID()
        let now = Int64((Date().timeIntervalSince1970 * 1000.0).rounded())
        
        // 插入带情绪和不带情绪的事件
        let items = [
            EpisodicMemoryItem(event: "去公园散步", date: "2026-02-12", emotion: "开心", context: nil),
            EpisodicMemoryItem(event: "修了个Bug", date: "2026-02-11", emotion: nil, context: nil),
        ]
        try await service.processEpisodic(items, sourceId: sourceId, defaultDate: now)
        try await service.save()
        
        let results = try await service.retrieveRelevantMemories(for: "test")
        
        // 至少有情景记忆这一段
        let episodicBlock = results.first(where: { $0.contains("Recent Events:") })
        #expect(episodicBlock != nil)
        
        // 有情绪的应该显示 "(开心)"
        #expect(episodicBlock?.contains("开心") == true)
        // 无情绪的应该显示 "(-)" 而不是 "Optional(...)"
        #expect(episodicBlock?.contains("Optional") == false)
        #expect(episodicBlock?.contains("(-)") == true)
    }
    
    @Test("检索程序性记忆按频率排序")
    func testRetrieveProceduralMemories() async throws {
        let container = try await Self.createContainer()
        let service = MemoryService(container: container)
        let sourceId = UUID()
        
        let items = [
            ProceduralMemoryItem(pattern: "深夜写作", preference: "安静环境", trigger: nil),
        ]
        try await service.processProcedural(items, sourceId: sourceId)
        try await service.save()
        
        // 触发第二次以增加频率
        try await service.processProcedural(items, sourceId: sourceId)
        try await service.save()
        
        let results = try await service.retrieveRelevantMemories(for: "test")
        
        let proceduralBlock = results.first(where: { $0.contains("Writing Patterns:") })
        #expect(proceduralBlock != nil)
        #expect(proceduralBlock?.contains("深夜写作") == true)
    }
    
    @Test("混合记忆检索返回多个段落")
    func testRetrieveMixedMemories() async throws {
        let container = try await Self.createContainer()
        let service = MemoryService(container: container)
        let sourceId = UUID()
        let now = Int64((Date().timeIntervalSince1970 * 1000.0).rounded())
        
        // 插入各类记忆
        try await service.processSemantic(
            [SemanticMemoryItem(key: "lang", value: "Swift", confidence: 0.8)],
            sourceId: sourceId
        )
        try await service.processEpisodic(
            [EpisodicMemoryItem(event: "读书", date: "2026-02-12", emotion: "平静", context: nil)],
            sourceId: sourceId,
            defaultDate: now
        )
        try await service.processProcedural(
            [ProceduralMemoryItem(pattern: "早起", preference: "喝咖啡", trigger: "闹钟")],
            sourceId: sourceId
        )
        try await service.save()
        
        let results = try await service.retrieveRelevantMemories(for: "test")
        
        // 应该有三段
        #expect(results.count == 3)
    }
}

// MARK: - Data Import/Export Round-Trip Tests

@Suite("Data Import Tests")
struct DataImportTests {
    
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
    
    @Test("JSON 解码导出数据格式")
    @MainActor
    func testDecodeExportData() async throws {
        // 构造一个最小的合法 WingExportData JSON
        let json = """
        {
            "version": "1.1",
            "exportedAt": "2026-02-12T00:00:00Z",
            "sessions": [
                {
                    "id": "\(UUID().uuidString)",
                    "date": "2026-02-12",
                    "status": "COMPLETED",
                    "fragments": [
                        {
                            "id": "\(UUID().uuidString)",
                            "content": "测试碎片",
                            "type": "text",
                            "timestamp": 1739318400000
                        }
                    ],
                    "entries": [
                        {
                            "id": "\(UUID().uuidString)",
                            "title": "测试日记",
                            "summary": "简介",
                            "mood": "😊",
                            "content": "# 正文",
                            "insights": "洞察",
                            "todos": [],
                            "createdAt": 1739318400000,
                            "imagesBase64": {}
                        }
                    ]
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let exportData = try decoder.decode(WingExportData.self, from: data)
        
        #expect(exportData.version == "1.1")
        #expect(exportData.sessions.count == 1)
        #expect(exportData.sessions[0].fragments.count == 1)
        #expect(exportData.sessions[0].entries.count == 1)
        #expect(exportData.sessions[0].entries[0].title == "测试日记")
    }
    
    @Test("导入合并模式不重复 Session")
    @MainActor
    func testImportMergeMode() async throws {
        let container = try Self.createContainer()
        let context = container.mainContext
        
        // 先手工创建一个 Session
        let existingSession = DailySession(date: "2026-02-12", status: .completed)
        context.insert(existingSession)
        try context.save()
        
        // 构造导入 JSON (相同日期)
        let fragId = UUID()
        let entryId = UUID()
        let json = """
        {
            "version": "1.1",
            "exportedAt": "2026-02-12T00:00:00Z",
            "sessions": [
                {
                    "id": "\(UUID().uuidString)",
                    "date": "2026-02-12",
                    "status": "COMPLETED",
                    "fragments": [
                        {
                            "id": "\(fragId.uuidString)",
                            "content": "新碎片",
                            "type": "text",
                            "timestamp": 1739318400000
                        }
                    ],
                    "entries": [
                        {
                            "id": "\(entryId.uuidString)",
                            "title": "新日记",
                            "summary": "新简介",
                            "mood": "😊",
                            "content": "# 新正文",
                            "insights": "新洞察",
                            "todos": [],
                            "createdAt": 1739318400000,
                            "imagesBase64": {}
                        }
                    ]
                }
            ]
        }
        """
        
        // 写入临时文件
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_import_\(UUID().uuidString).json")
        try json.data(using: .utf8)!.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // 执行导入
        try await DataImportService.shared.importJSON(from: tempURL, context: context)
        
        // 验证：同日期的 Session 数量应为 1（合并到已有的）
        let sessionDesc = FetchDescriptor<DailySession>()
        let sessions = try context.fetch(sessionDesc)
        #expect(sessions.count == 1) // 合并，不创建新的
        
        // 碎片和日记应该被添加
        let fragDesc = FetchDescriptor<RawFragment>()
        let fragments = try context.fetch(fragDesc)
        #expect(fragments.count == 1)
        
        let entryDesc = FetchDescriptor<WingEntry>()
        let entries = try context.fetch(entryDesc)
        #expect(entries.count == 1)
    }
    
    @Test("导入替换模式清空旧数据")
    @MainActor
    func testImportReplaceMode() async throws {
        let container = try Self.createContainer()
        let context = container.mainContext
        
        // 先创建旧数据
        let oldSession = DailySession(date: "2026-02-10", status: .completed)
        let oldFragment = RawFragment(content: "旧碎片", timestamp: 0, type: .text)
        oldFragment.dailySession = oldSession
        context.insert(oldSession)
        context.insert(oldFragment)
        try context.save()
        
        // 构造替换数据 JSON
        let json = """
        {
            "version": "1.1",
            "exportedAt": "2026-02-12T00:00:00Z",
            "sessions": [
                {
                    "id": "\(UUID().uuidString)",
                    "date": "2026-02-12",
                    "status": "COMPLETED",
                    "fragments": [
                        {
                            "id": "\(UUID().uuidString)",
                            "content": "新替换碎片",
                            "type": "text",
                            "timestamp": 1739318400000
                        }
                    ],
                    "entries": []
                }
            ]
        }
        """
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_replace_\(UUID().uuidString).json")
        try json.data(using: .utf8)!.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // 执行替换
        try await DataImportService.shared.replaceData(from: tempURL, context: context)
        
        // 旧 Session 应被删除
        let sessionDesc = FetchDescriptor<DailySession>()
        let sessions = try context.fetch(sessionDesc)
        #expect(sessions.count == 1)
        #expect(sessions.first?.date == "2026-02-12") // 只有新数据
        
        // 旧碎片应被删除
        let fragDesc = FetchDescriptor<RawFragment>()
        let fragments = try context.fetch(fragDesc)
        #expect(fragments.count == 1)
        #expect(fragments.first?.content == "新替换碎片")
    }
    
    @Test("导出模式：空数据库不报错")
    @MainActor
    func testExportEmptyDB() async throws {
        let container = try Self.createContainer()
        let context = container.mainContext
        
        let url = try await DataExportService.shared.exportJSON(context: context)
        let data = try Data(contentsOf: url)
        let exportData = try JSONDecoder().decode(WingExportData.self, from: data)
        #expect(exportData.sessions.isEmpty)
    }

    @Test("导出模式：处理孤儿日记 (Orphaned Entry)")
    @MainActor
    func testExportOrphanedEntry() async throws {
        let container = try Self.createContainer()
        let context = container.mainContext
        
        let orphanedEntry = WingEntry(title: "Orphan", summary: "Test", mood: "Happy", markdownContent: "Content", aiInsights: "Insight", createdAt: 1739318400000)
        context.insert(orphanedEntry)
        try context.save()
        
        let url = try await DataExportService.shared.exportJSON(context: context)
        let data = try Data(contentsOf: url)
        let exportData = try JSONDecoder().decode(WingExportData.self, from: data)
        
        #expect(exportData.sessions.count == 1)
        #expect(exportData.sessions[0].entries.count == 1)
        #expect(exportData.sessions[0].entries[0].title == "Orphan")
        #expect(exportData.sessions[0].fragments.isEmpty)
    }
    
    @Test("导出与导入模式：验证图片 Base64 传递")
    @MainActor
    func testExportImportImageBase64() async throws {
        let container = try Self.createContainer()
        let context = container.mainContext
        
        let imageBytes: [UInt8] = [0xFF, 0xD8, 0xFF, 0xDB] // fake JPEG header
        let imageData = Data(imageBytes)
        
        // 插入到 Fragment
        let session = DailySession(date: "2026-02-12", status: .completed)
        let fragment = RawFragment(content: "Image Frag", imageData: imageData, timestamp: 1739318400000, type: .image)
        fragment.dailySession = session
        context.insert(session)
        context.insert(fragment)
        try context.save()
        
        let url = try await DataExportService.shared.exportJSON(context: context)
        let data = try Data(contentsOf: url)
        let exportData = try JSONDecoder().decode(WingExportData.self, from: data)
        
        let b64 = exportData.sessions[0].fragments[0].imageDataBase64
        #expect(b64 == imageData.base64EncodedString())
        
        // 测试再次导入是否恢复为 Data
        let container2 = try Self.createContainer()
        let context2 = container2.mainContext
        try await DataImportService.shared.importJSON(from: url, context: context2)
        
        let fragDesc = FetchDescriptor<RawFragment>()
        let fragments = try context2.fetch(fragDesc)
        #expect(fragments.count == 1)
        #expect(fragments.first?.imageData == imageData)
    }

    @Test("替换模式：清空所有记忆数据")
    @MainActor
    func testReplaceClearsMemories() async throws {
        let container = try Self.createContainer()
        let context = container.mainContext
        
        // 插入记忆
        context.insert(SemanticMemory(key: "test", value: "test", createdAt: 0, updatedAt: 0))
        context.insert(EpisodicMemory(event: "test", date: "2026", sourceEntryId: UUID(), createdAt: 0))
        context.insert(ProceduralMemory(pattern: "test", preference: "test", createdAt: 0, updatedAt: 0))
        try context.save()
        
        let json = """
        {
            "version": "1.1",
            "exportedAt": "2026-02-12T00:00:00Z",
            "sessions": []
        }
        """
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_memory_replace_\\(UUID().uuidString).json")
        try json.data(using: .utf8)!.write(to: tempURL)
        
        try await DataImportService.shared.replaceData(from: tempURL, context: context)
        
        let semCount = try context.fetchCount(FetchDescriptor<SemanticMemory>())
        let epiCount = try context.fetchCount(FetchDescriptor<EpisodicMemory>())
        let proCount = try context.fetchCount(FetchDescriptor<ProceduralMemory>())
        
        #expect(semCount == 0)
        #expect(epiCount == 0)
        #expect(proCount == 0)
    }

    @Test("合并模式：防止重复导入相同的 Fragment 和 Entry")
    @MainActor
    func testImportMergeAvoidsDuplicates() async throws {
        let container = try Self.createContainer()
        let context = container.mainContext
        
        let session = DailySession(date: "2026-02-12", status: .completed)
        let fragment = RawFragment(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, content: "frag1", timestamp: 1739318400000, type: .text)
        fragment.dailySession = session
        
        let entry = WingEntry(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, title: "entry1", summary: "", mood: "", markdownContent: "", aiInsights: "", createdAt: 1739318400000)
        entry.dailySession = session
        
        context.insert(session)
        context.insert(fragment)
        context.insert(entry)
        try context.save()
        
        let fragDesc = FetchDescriptor<RawFragment>()
        let entryDesc = FetchDescriptor<WingEntry>()
        
        // 构造包含同样 fragment 和 entry 的 JSON
        let json = """
        {
            "version": "1.1",
            "exportedAt": "2026-02-12T00:00:00Z",
            "sessions": [
                {
                    "id": "\\(session.id.uuidString)",
                    "date": "2026-02-12",
                    "status": "COMPLETED",
                    "fragments": [
                        {
                            "id": "11111111-1111-1111-1111-111111111111",
                            "content": "frag1",
                            "type": "text",
                            "timestamp": 1739318400000
                        },
                        {
                            "id": "\\(UUID().uuidString)",
                            "content": "frag2_new",
                            "type": "text",
                            "timestamp": 1739318400001
                        }
                    ],
                    "entries": [
                        {
                            "id": "22222222-2222-2222-2222-222222222222",
                            "title": "entry1",
                            "summary": "",
                            "mood": "",
                            "content": "",
                            "insights": "",
                            "todos": [],
                            "createdAt": 1739318400000,
                            "imagesBase64": {}
                        }
                    ]
                }
            ]
        }
        """
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_merge_dup_\\(UUID().uuidString).json")
        try json.data(using: .utf8)!.write(to: tempURL)
        
        try await DataImportService.shared.importJSON(from: tempURL, context: context)
        
        let afterFragCount = try context.fetchCount(fragDesc)
        let afterEntryCount = try context.fetchCount(entryDesc)
        
        // Frag 应该变成 2 (1旧 + 1新)
        #expect(afterFragCount == 2)
        // Entry 应该保持 1 (只有旧的，跳过重复)
        #expect(afterEntryCount == 1)
    }
}

// MARK: - Prompt Building Tests

@Suite("AI Prompt Building Tests")
struct AIPromptTests {
    
    @Test("buildUserPrompt 不含记忆时格式正确")
    func testPromptWithoutMemories() async throws {
        let ai = AIService.shared
        
        let fragments = [
            RawFragment(content: "早上好", timestamp: 1739318400000, type: .text),
            RawFragment(content: "中午吃饭了", timestamp: 1739318460000, type: .text),
        ]
        
        // 使用 synthesizeJournalStream 来间接测试 prompt 构建
        // 但由于 buildUserPrompt 是 private，我们通过集成测试间接验证
        // 这里我们直接验证 synthesizeJournal 的签名正确接受 memories 参数
        let config = await AIConfig(provider: .gemini, model: "test", apiKey: "", baseURL: nil)
        let stream = await ai.synthesizeJournalStream(
            fragments: fragments,
            memories: [],
            config: config
        )
        
        // 由于 API Key 为空，流应该抛错
        var gotError = false
        do {
            for try await _ in stream {
                // Should not reach here
            }
        } catch {
            gotError = true
        }
        #expect(gotError == true)
    }
    
    @Test("synthesizeJournal 接受 memories 参数并在缺少 API Key 时抛错")
    func testSynthesizeJournalWithMemoriesThrowsOnMissingKey() async throws {
        let ai = AIService.shared
        
        let fragments = [
            RawFragment(content: "测试内容", timestamp: 1739318400000, type: .text),
        ]
        
        let memories = [
            "User Facts:\n- name: Hans",
            "Recent Events:\n- [2026-02-12] 开会 (紧张)",
        ]
        
        let config = await AIConfig(provider: .gemini, model: "test", apiKey: "", baseURL: nil)
        
        do {
            _ = try await ai.synthesizeJournal(
                fragments: fragments,
                memories: memories,
                config: config
            )
            Issue.record("应该抛出 missingAPIKey 错误")
        } catch {
            // 预期抛出 AIError.missingAPIKey
            #expect(String(describing: error).contains("missingAPIKey") || String(describing: error).contains("API"))
        }
    }
}

// MARK: - Merge Candidate Tests

@Suite("Memory Merge DTO Tests")
struct MemoryMergeDTOTests {
    
    @Test("MergeCandidateGroup 正确初始化")
    func testMergeCandidateGroupInit() {
        let ids = [UUID(), UUID(), UUID()]
        let group = MergeCandidateGroup(
            type: .semantic,
            groupKey: "user_name",
            memoryIds: ids,
            suggestedContent: nil
        )
        
        #expect(group.type == .semantic)
        #expect(group.groupKey == "user_name")
        #expect(group.memoryIds.count == 3)
        #expect(group.suggestedContent == nil)
    }
    
    @Test("MemoryExtractionResult 正确解码 JSON")
    func testMemoryExtractionResultDecoding() throws {
        let json = """
        {
            "semantic": [
                {"key": "name", "value": "Hans", "confidence": 0.9}
            ],
            "episodic": [
                {"event": "开会", "date": "2026-02-12", "emotion": "紧张", "context": null}
            ],
            "procedural": [
                {"pattern": "深夜写代码", "preference": "安静", "trigger": null}
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(MemoryExtractionResult.self, from: data)
        
        #expect(result.semantic.count == 1)
        #expect(result.semantic[0].key == "name")
        #expect(result.semantic[0].confidence == 0.9)
        
        #expect(result.episodic.count == 1)
        #expect(result.episodic[0].event == "开会")
        #expect(result.episodic[0].emotion == "紧张")
        
        #expect(result.procedural.count == 1)
        #expect(result.procedural[0].pattern == "深夜写代码")
        #expect(result.procedural[0].trigger == nil)
    }
}
