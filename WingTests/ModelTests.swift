//
//  ModelTests.swift
//  WingTests
//
//  Created on 2026-01-28.
//

import Testing
import SwiftData
import SwiftUI
import UIKit
@testable import Wing

/// 测试套件：Wing 数据模型测试
struct ModelTests {
    
    /// 创建内存中的 ModelContainer 用于测试
    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            DailySession.self,
            WingEntry.self,
            RawFragment.self,
            SemanticMemory.self,
            EpisodicMemory.self,
            ProceduralMemory.self,
            AppSettings.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
    
    /// 生成测试用的图片数据（使用 SF Symbol）
    private func createTestImageData() -> Data? {
        guard let image = UIImage(systemName: "star.fill") else {
            return nil
        }
        return image.pngData()
    }
    
    // MARK: - CRUD 测试
    
    /**
     * 测试 CRUD 操作
     * 创建一个 DailySession，添加几个 RawFragment，保存，然后查询出来，验证数据一致性
     */
    @Test("CRUD: 创建、读取、更新、删除 DailySession 和 RawFragment")
    @MainActor
    func testCRUD() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        
        // 创建 DailySession - 先创建 UUID 常量用于 Predicate
        let sessionId = UUID()
        let date = "2026-01-28"
        let session = DailySession(
            id: sessionId,
            date: date,
            status: .recording
        )
        
        // 创建几个 RawFragment
        let fragment1 = RawFragment(
            id: UUID(),
            content: "今天天气真好",
            timestamp: Int64(Date().timeIntervalSince1970 * 1000),
            type: .text
        )
        
        let fragment2 = RawFragment(
            id: UUID(),
            content: "完成了重要的工作",
            timestamp: Int64(Date().timeIntervalSince1970 * 1000) + 1000,
            type: .text
        )
        
        let fragment3 = RawFragment(
            id: UUID(),
            content: "晚上去散步",
            timestamp: Int64(Date().timeIntervalSince1970 * 1000) + 2000,
            type: .text
        )
        
        // 建立关系
        session.fragments.append(fragment1)
        session.fragments.append(fragment2)
        session.fragments.append(fragment3)
        fragment1.dailySession = session
        fragment2.dailySession = session
        fragment3.dailySession = session
        
        // 保存
        context.insert(session)
        context.insert(fragment1)
        context.insert(fragment2)
        context.insert(fragment3)
        try context.save()
        
        // 查询 DailySession - 使用常量 UUID
        let descriptor = FetchDescriptor<DailySession>(
            predicate: #Predicate<DailySession> { session in
                session.id == sessionId
            }
        )
        let fetchedSessions = try context.fetch(descriptor)
        
        #expect(fetchedSessions.count == 1)
        let fetchedSession = fetchedSessions[0]
        
        #expect(fetchedSession.date == date)
        #expect(fetchedSession.status == .recording)
        #expect(fetchedSession.fragments.count == 3)
        
        // 验证 fragments 内容
        let fragmentContents = fetchedSession.fragments.map { $0.content }.sorted()
        #expect(fragmentContents == ["今天天气真好", "完成了重要的工作", "晚上去散步"])
        
        // 验证时间戳顺序
        let timestamps = fetchedSession.fragments.map { $0.timestamp }.sorted()
        #expect(timestamps[0] < timestamps[1])
        #expect(timestamps[1] < timestamps[2])
        
        // 测试更新
        fetchedSession.status = .processing
        try context.save()
        
        let updatedDescriptor = FetchDescriptor<DailySession>(
            predicate: #Predicate<DailySession> { session in
                session.id == sessionId
            }
        )
        let updatedSessions = try context.fetch(updatedDescriptor)
        #expect(updatedSessions[0].status == .processing)
        
        // 测试删除
        context.delete(fetchedSession)
        try context.save()
        
        let deletedDescriptor = FetchDescriptor<DailySession>(
            predicate: #Predicate<DailySession> { session in
                session.id == sessionId
            }
        )
        let deletedSessions = try context.fetch(deletedDescriptor)
        #expect(deletedSessions.isEmpty)
    }
    
    // MARK: - 图片存储测试
    
    /**
     * 测试图片存储
     * 创建一个带图片的 RawFragment，保存，验证 imageData 字段不为空
     */
    @Test("图片存储: 验证 RawFragment 的 imageData 字段正确存储")
    @MainActor
    func testImageStorage() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        
        // 创建测试图片数据
        guard let imageData = createTestImageData() else {
            Issue.record("无法创建测试图片数据")
            return
        }
        
        #expect(imageData.count > 0)
        
        // 创建带图片的 RawFragment - 先创建 UUID 常量
        let fragmentId = UUID()
        let fragment = RawFragment(
            id: fragmentId,
            content: "这是一张测试图片",
            imageData: imageData,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000),
            type: .image
        )
        
        // 保存
        context.insert(fragment)
        try context.save()
        
        // 查询并验证 - 使用常量 UUID
        let descriptor = FetchDescriptor<RawFragment>(
            predicate: #Predicate<RawFragment> { fragment in
                fragment.id == fragmentId
            }
        )
        let fetchedFragments = try context.fetch(descriptor)
        
        #expect(fetchedFragments.count == 1)
        let fetchedFragment = fetchedFragments[0]
        
        // 验证图片数据不为空
        #expect(fetchedFragment.imageData != nil)
        #expect(fetchedFragment.type == .image)
        
        // 验证图片数据内容一致
        if let fetchedImageData = fetchedFragment.imageData {
            #expect(fetchedImageData.count == imageData.count)
            #expect(fetchedImageData == imageData)
        } else {
            Issue.record("图片数据为空")
        }
        
        // 验证 content 字段
        #expect(fetchedFragment.content == "这是一张测试图片")
    }
    
    // MARK: - 级联删除测试
    
    /**
     * 测试级联删除
     * 删除 DailySession，验证其关联的 fragments 是否也会自动从数据库中消失
     */
    @Test("级联删除: 删除 DailySession 时自动删除关联的 RawFragment")
    @MainActor
    func testCascadeDelete() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        
        // 创建 DailySession - 先创建 UUID 常量
        let sessionId = UUID()
        let session = DailySession(
            id: sessionId,
            date: "2026-01-28",
            status: .recording
        )
        
        // 创建多个 RawFragment - 先创建 UUID 常量
        let fragment1Id = UUID()
        let fragment2Id = UUID()
        let fragment3Id = UUID()
        
        let fragment1 = RawFragment(
            id: fragment1Id,
            content: "片段 1",
            timestamp: Int64(Date().timeIntervalSince1970 * 1000),
            type: .text
        )
        
        let fragment2 = RawFragment(
            id: fragment2Id,
            content: "片段 2",
            timestamp: Int64(Date().timeIntervalSince1970 * 1000) + 1000,
            type: .text
        )
        
        let fragment3 = RawFragment(
            id: fragment3Id,
            content: "片段 3",
            timestamp: Int64(Date().timeIntervalSince1970 * 1000) + 2000,
            type: .text
        )
        
        // 建立关系
        session.fragments.append(fragment1)
        session.fragments.append(fragment2)
        session.fragments.append(fragment3)
        fragment1.dailySession = session
        fragment2.dailySession = session
        fragment3.dailySession = session
        
        // 保存
        context.insert(session)
        context.insert(fragment1)
        context.insert(fragment2)
        context.insert(fragment3)
        try context.save()
        
        // 验证保存成功
        let sessionDescriptor = FetchDescriptor<DailySession>(
            predicate: #Predicate<DailySession> { session in
                session.id == sessionId
            }
        )
        let sessions = try context.fetch(sessionDescriptor)
        #expect(sessions.count == 1)
        #expect(sessions[0].fragments.count == 3)
        
        let fragmentDescriptor = FetchDescriptor<RawFragment>()
        let allFragments = try context.fetch(fragmentDescriptor)
        #expect(allFragments.count == 3)
        
        // 删除 DailySession
        context.delete(session)
        try context.save()
        
        // 验证 DailySession 已被删除
        let deletedSessions = try context.fetch(sessionDescriptor)
        #expect(deletedSessions.isEmpty)
        
        // 验证关联的 fragments 也被级联删除
        let remainingFragments = try context.fetch(fragmentDescriptor)
        #expect(remainingFragments.isEmpty, "级联删除失败：fragments 应该被自动删除")
        
        // 单独验证每个 fragment 都不存在
        let fragment1Descriptor = FetchDescriptor<RawFragment>(
            predicate: #Predicate<RawFragment> { fragment in
                fragment.id == fragment1Id
            }
        )
        let fragment2Descriptor = FetchDescriptor<RawFragment>(
            predicate: #Predicate<RawFragment> { fragment in
                fragment.id == fragment2Id
            }
        )
        let fragment3Descriptor = FetchDescriptor<RawFragment>(
            predicate: #Predicate<RawFragment> { fragment in
                fragment.id == fragment3Id
            }
        )
        
        #expect(try context.fetch(fragment1Descriptor).isEmpty)
        #expect(try context.fetch(fragment2Descriptor).isEmpty)
        #expect(try context.fetch(fragment3Descriptor).isEmpty)
    }
    
    // MARK: - 额外测试：WingEntry 和 DailySession 的关系
    
    /**
     * 测试 WingEntry 和 DailySession 的关系
     */
    @Test("关系测试: WingEntry 和 DailySession 的关联")
    @MainActor
    func testWingEntryRelationship() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        
        // 创建 DailySession - 先创建 UUID 常量
        let sessionId = UUID()
        let session = DailySession(
            id: sessionId,
            date: "2026-01-28",
            status: .completed
        )
        
        // 创建 WingEntry - 先创建 UUID 常量
        let entryId = UUID()
        let entry = WingEntry(
            id: entryId,
            title: "测试日记",
            summary: "这是一篇测试日记",
            mood: "😊",
            markdownContent: "# 测试日记\n\n这是正文内容",
            aiInsights: "测试洞察",
            todos: [
                WingTodo(title: "待办1", priority: .high),
                WingTodo(title: "待办2", priority: .medium)
            ],
            createdAt: Int64(Date().timeIntervalSince1970 * 1000)
        )
        
        // 建立关系
        session.finalEntry = entry
        session.finalEntryId = entryId
        entry.dailySession = session
        
        // 保存
        context.insert(session)
        context.insert(entry)
        try context.save()
        
        // 验证关系 - 使用常量 UUID
        let sessionDescriptor = FetchDescriptor<DailySession>(
            predicate: #Predicate<DailySession> { session in
                session.id == sessionId
            }
        )
        let fetchedSessions = try context.fetch(sessionDescriptor)
        #expect(fetchedSessions.count == 1)
        
        let fetchedSession = fetchedSessions[0]
        #expect(fetchedSession.finalEntry != nil)
        #expect(fetchedSession.finalEntry?.id == entryId)
        #expect(fetchedSession.finalEntry?.title == "测试日记")
        #expect(fetchedSession.finalEntry?.todos.count == 2)
    }
    
    // MARK: - 额外测试：复杂数据类型存储
    
    /**
     * 测试复杂数据类型的存储（todos, editHistory, images）
     */
    @Test("复杂数据: 测试 WingEntry 的 todos、editHistory、images 存储")
    @MainActor
    func testComplexDataStorage() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        
        // 创建测试图片数据
        guard let imageData = createTestImageData() else {
            Issue.record("无法创建测试图片数据")
            return
        }
        
        let imageId1 = UUID()
        let imageId2 = UUID()
        
        // 创建 WingEntry 带复杂数据 - 先创建 UUID 常量
        let entryId = UUID()
        let entry = WingEntry(
            id: entryId,
            title: "复杂数据测试",
            summary: "测试",
            mood: "😊",
            markdownContent: "# 测试",
            aiInsights: "测试",
            todos: [
                WingTodo(title: "高优先级", priority: .high, completed: false),
                WingTodo(title: "中优先级", priority: .medium, completed: true),
                WingTodo(title: "低优先级", priority: .low, completed: false)
            ],
            createdAt: Int64(Date().timeIntervalSince1970 * 1000),
            editHistory: [
                EditHistoryItem(
                    createdAt: Int64(Date().timeIntervalSince1970 * 1000) - 1000,
                    title: "旧标题",
                    markdownContent: "旧内容"
                )
            ],
            images: [
                imageId1: imageData,
                imageId2: imageData
            ]
        )
        
        // 保存
        context.insert(entry)
        try context.save()
        
        // 查询并验证 - 使用常量 UUID
        let descriptor = FetchDescriptor<WingEntry>(
            predicate: #Predicate<WingEntry> { entry in
                entry.id == entryId
            }
        )
        let fetchedEntries = try context.fetch(descriptor)
        
        #expect(fetchedEntries.count == 1)
        let fetchedEntry = fetchedEntries[0]
        
        // 验证 todos
        #expect(fetchedEntry.todos.count == 3)
        #expect(fetchedEntry.todos[0].title == "高优先级")
        #expect(fetchedEntry.todos[0].priority == .high)
        #expect(fetchedEntry.todos[1].completed == true)
        
        // 验证 editHistory
        #expect(fetchedEntry.editHistory.count == 1)
        #expect(fetchedEntry.editHistory[0].title == "旧标题")
        #expect(fetchedEntry.editHistory[0].markdownContent == "旧内容")
        
        // 验证 images
        #expect(fetchedEntry.images.count == 2)
        #expect(fetchedEntry.images[imageId1] != nil)
        #expect(fetchedEntry.images[imageId2] != nil)
        #expect(fetchedEntry.images[imageId1]?.count == imageData.count)
    }
}
