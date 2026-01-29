//
//  TestDataInjector.swift
//  Wing
//
//  Created on 2026-01-29.
//

import Foundation
import SwiftData
import UIKit

/**
 * 测试数据注入工具
 *
 * 用于在开发和测试阶段快速生成模拟数据
 */
actor TestDataInjector {
    
    /**
     * 注入测试数据到 ModelContext
     *
     * 包含：
     * - 今天的 Session 和多条碎片（文本 + 图片）
     * - 昨天的 Session 和碎片
     * - 一周前的 Session 和碎片
     *
     * 注意：仅在数据库为空时才注入，避免重复创建
     */
    func injectTestData(context: ModelContext) async {
        // 检查是否已有数据，避免重复注入
        let descriptor = FetchDescriptor<DailySession>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        
        guard existingCount == 0 else {
            print("TestDataInjector: 数据库已有 \(existingCount) 个 Session，跳过注入")
            return
        }
        
        print("TestDataInjector: 数据库为空，开始注入测试数据...")
        
        // 1. 创建今天的 Session
        let today = getCurrentDateString()
        let todaySession = DailySession(date: today, status: .recording)
        context.insert(todaySession)
        
        // 添加今天的碎片
        await addFragments(to: todaySession, context: context, count: 5)
        
        // 2. 创建昨天的 Session
        let yesterday = getDateString(daysAgo: 1)
        let yesterdaySession = DailySession(date: yesterday, status: .completed)
        context.insert(yesterdaySession)
        
        await addFragments(to: yesterdaySession, context: context, count: 3)
        
        // 3. 创建一周前的 Session
        let weekAgo = getDateString(daysAgo: 7)
        let weekAgoSession = DailySession(date: weekAgo, status: .completed)
        context.insert(weekAgoSession)
        
        await addFragments(to: weekAgoSession, context: context, count: 4)
        
        // 保存
        try? context.save()
        print("TestDataInjector: 测试数据注入完成")
    }
    
    // MARK: - Helper Methods
    
    private func addFragments(to session: DailySession, context: ModelContext, count: Int) async {
        let baseTime = getTimestamp(for: session.date)
        
        for i in 0..<count {
            // 每条消息间隔 10 分钟
            let timestamp = baseTime + Int64(i * 10 * 60 * 1000)
            
            if i % 3 == 0 {
                // 每 3 条添加一张图片
                let fragment = RawFragment(
                    content: "这是第 \(i + 1) 张图片",
                    imageData: await generateTestImage(),
                    timestamp: timestamp,
                    type: .image
                )
                fragment.dailySession = session
                session.fragments.append(fragment)
                context.insert(fragment)
            } else {
                // 文本消息
                let content = getTestText(index: i)
                let fragment = RawFragment(
                    content: content,
                    timestamp: timestamp,
                    type: .text
                )
                fragment.dailySession = session
                session.fragments.append(fragment)
                context.insert(fragment)
            }
        }
    }
    
    private func getTestText(index: Int) -> String {
        let texts = [
            "今天天气真好，阳光明媚 ☀️",
            "刚刚完成了一个重要的项目，感觉很有成就感！",
            "午餐吃了很美味的拉面 🍜",
            "下午和朋友喝了咖啡，聊了很多有趣的话题",
            "晚上准备看一部电影放松一下",
            "最近在学习 SwiftUI，感觉很有意思",
            "今天遇到了一个技术难题，花了很长时间才解决",
            "周末计划去爬山，期待！",
            "读了一本很棒的书，收获很多",
            "今天的锻炼完成了，感觉精神状态很好 💪"
        ]
        return texts[index % texts.count]
    }
    
    private func generateTestImage() async -> Data? {
        // 生成一个简单的彩色方块作为测试图片
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // 随机颜色背景
            let colors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemPink]
            let randomColor = colors.randomElement() ?? .systemBlue
            randomColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 添加文字
            let text = "测试图片"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        // 压缩图片
        let compressor = ImageCompressor()
        return await compressor.compress(image.jpegData(compressionQuality: 0.9) ?? Data())
    }
    
    private func getCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func getDateString(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func getTimestamp(for dateString: String) -> Int64 {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            return Int64(date.timeIntervalSince1970 * 1000)
        }
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    /**
     * 清空所有数据（谨慎使用）
     */
    private func clearAllData(context: ModelContext) {
        // 删除所有 DailySession（会级联删除 RawFragment）
        let descriptor = FetchDescriptor<DailySession>()
        if let sessions = try? context.fetch(descriptor) {
            for session in sessions {
                context.delete(session)
            }
        }
        
        try? context.save()
    }
}
