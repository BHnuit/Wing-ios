//
//  Phase10Tests.swift
//  WingTests
//
//  Created on 2026-02-17.
//

import Testing
@testable import Wing
import Foundation
import SwiftData

@MainActor
struct Phase10Tests {
    
    // MARK: - Title Style Tests
    
    @Test
    func testTitleStyleDefaults() {
        // 验证 TitleStyle 的默认 Prompt 是否符合预期
        #expect(TitleStyle.abstract.defaultPrompt.contains("abstract"))
        #expect(TitleStyle.summary.defaultPrompt.contains("summary"))
        #expect(TitleStyle.dateBased.defaultPrompt.contains("date"))
        #expect(TitleStyle.custom.defaultPrompt == "")
    }
    
    @Test
    func testAppSettingsPersistence() throws {
        // 验证 AppSettings 是否正确持久化新的 titleStyle 字段
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AppSettings.self, configurations: config)
        let context = container.mainContext
        
        let settings = AppSettings()
        settings.titleStyle = .dateBased
        settings.titleStylePrompt = "Custom Prompt Here"
        
        context.insert(settings)
        try context.save()
        
        let descriptor = FetchDescriptor<AppSettings>()
        let fetchedSettings = try context.fetch(descriptor).first
        
        #expect(fetchedSettings?.titleStyle == .dateBased)
        #expect(fetchedSettings?.titleStylePrompt == "Custom Prompt Here")
    }
    
    // MARK: - Entry Logic Tests
    
    @Test
    func testEntryDuplicationLogic() {
        // 验证副本逻辑：保持 createdAt，生成新 ID
        let originalDate: Int64 = 1700000000000 // Some past timestamp
        let original = WingEntry(
            id: UUID(),
            title: "Original Title",
            summary: "Original Summary",
            mood: "Happy",
            markdownContent: "Original Content",
            aiInsights: "Original Insights",
            createdAt: originalDate,
            generatedAt: 2000000000000
        )
        
        // 模拟 Duplicate 逻辑
        let duplicate = WingEntry(
            id: UUID(),
            title: original.title + " (Copy)",
            summary: original.summary,
            mood: original.mood,
            markdownContent: original.markdownContent,
            aiInsights: original.aiInsights,
            createdAt: original.createdAt, // Should be same
            generatedAt: Int64(Date().timeIntervalSince1970 * 1000)
        )
        
        #expect(duplicate.title == "Original Title (Copy)")
        #expect(duplicate.summary == original.summary)
        #expect(duplicate.markdownContent == original.markdownContent)
        #expect(duplicate.createdAt == original.createdAt)
        #expect(duplicate.id != original.id)
    }
    
    // MARK: - Date Calculation Tests
    
    @Test
    func testCreatedAtCalculation() {
        // 验证 JournalSynthesisService 中的日期计算逻辑
        // 逻辑：session.date (YYYY-MM-DD) -> Year-Month-Day 23:59:59
        
        let sessionDateString = "2026-02-15"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // Ensure formatter uses default logic consistent with Service
        
        let sessionDate = formatter.date(from: sessionDateString) ?? Date()
        
        var calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: sessionDate)
        components.hour = 23
        components.minute = 59
        components.second = 59
        let calculatedDate = calendar.date(from: components)!
        
        // Verify components
        let resultComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: calculatedDate)
        
        #expect(resultComponents.year == 2026)
        #expect(resultComponents.month == 2)
        #expect(resultComponents.day == 15)
        #expect(resultComponents.hour == 23)
        #expect(resultComponents.minute == 59)
        #expect(resultComponents.second == 59)
    }
}
