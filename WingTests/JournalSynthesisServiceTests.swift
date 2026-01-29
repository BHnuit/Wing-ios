//
//  JournalSynthesisServiceTests.swift
//  WingTests
//
//  Created on 2026-01-29.
//

import Testing
import SwiftData
@testable import Wing

/**
 * 日记合成服务测试
 */
struct JournalSynthesisServiceTests {
    
    /// 创建测试用的 ModelContainer
    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            DailySession.self,
            WingEntry.self,
            RawFragment.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
    
    /**
     * 测试 JournalOutput Fallback 机制
     */
    @Test("JournalOutput Fallback: 解析失败时返回无题日记")
    func testJournalOutputFallback() {
        let rawContent = "这是一段无法解析的文本内容"
        let output = JournalOutput.fallback(rawContent: rawContent)
        
        #expect(output.title == "无题日记")
        #expect(output.summary == "今日的记录")
        #expect(output.mood == "📝")
        #expect(output.content == rawContent)
        #expect(output.insights == "今天的想法已被记录下来。")
    }
    
    /**
     * 测试 SynthesisProgress 消息
     */
    @Test("SynthesisProgress: 验证分步文案")
    func testSynthesisProgressMessages() {
        #expect(SynthesisProgress.started.message == "正在收拢今日羽毛...")
        #expect(SynthesisProgress.generating.message == "正在编织日记...")
        #expect(SynthesisProgress.saving.message == "正在洞察感受...")
        #expect(SynthesisProgress.completed(entryId: UUID()).message == "完成 ✨")
    }
    
    /**
     * 测试 SynthesisError 本地化描述
     */
    @Test("SynthesisError: 验证错误消息")
    func testSynthesisErrorMessages() {
        #expect(SynthesisError.noFragments.errorDescription == "没有可用的碎片记录")
        #expect(SynthesisError.configurationMissing.errorDescription == "缺少 AI 配置，请在设置中配置 API Key")
    }
}
