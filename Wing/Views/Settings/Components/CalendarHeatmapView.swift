//
//  CalendarHeatmapView.swift
//  Wing
//
//  Created on 2026-02-12.
//

import SwiftUI

/**
 * 日历热力图组件
 * 展示过去一年的活跃度，类似 GitHub Contribution Graph
 */
struct CalendarHeatmapView: View {
    /// 所有会话数据
    var sessions: [DailySession]
    
    // MARK: - Configuration
    private let calendar = Calendar.current
    private let squareSize: CGFloat = 10
    private let spacing: CGFloat = 3
    
    // MARK: - Computed Data
    
    /// 结束日期（今天）
    private var endDate: Date {
        Date()
    }
    
    /// 开始日期（一年前）
    private var startDate: Date {
        // 大约 52 周前
        calendar.date(byAdding: .day, value: -(52 * 7), to: endDate) ?? Date()
    }
    
    /// 共享 DateFormatter，避免重复创建
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    /// 日期 -> 强度映射 (0-4)
    private var intensityMap: [String: Int] {
        var map: [String: Int] = [:]
        
        for session in sessions {
            let count = session.fragments.count
            var intensity = 0
            if count > 0 {
                // 根据碎片数量计算强度
                if count <= 2 { intensity = 1 }
                else if count <= 5 { intensity = 2 }
                else if count <= 10 { intensity = 3 }
                else { intensity = 4 }
            }
            map[session.date] = intensity
        }
        return map
    }
    
    /// 生成周数据 [[Date?]]
    /// 每一列是一周（从周日到周六），如果有空缺则为 nil
    private var weeks: [[Date?]] {
        var weeks: [[Date?]] = []
        var dates: [Date] = []
        
        // 1. 生成所有日期范围
        // 从 startDate 到 endDate
        var currentDate = startDate
        while currentDate <= endDate {
            dates.append(currentDate)
            guard let next = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = next
        }
        
        // 2. 补齐开头的空位 (如果 startDate 不是周日)
        let startWeekday = calendar.component(.weekday, from: startDate) // 1=Sun, 7=Sat
        let prefixCount = startWeekday - 1
        let prefix: [Date?] = Array(repeating: nil, count: prefixCount)
        
        var allDays: [Date?] = prefix + dates.map { Optional($0) }
        
        // 3. 分块为周 (7天一组)
        while !allDays.isEmpty {
            let chunkCount = min(7, allDays.count)
            let chunk = Array(allDays.prefix(chunkCount))
            allDays.removeFirst(chunkCount)
            
            var week = chunk
            // 如果最后一周不足7天，补齐
            if week.count < 7 {
                week.append(contentsOf: Array(repeating: nil, count: 7 - week.count))
            }
            weeks.append(week)
        }
        
        return weeks
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(weeks.indices, id: \.self) { weekIndex in
                        VStack(spacing: spacing) {
                            ForEach(0..<7) { dayIndex in
                                if let date = weeks[weekIndex][dayIndex] {
                                    DaySquare(
                                        date: date,
                                        intensity: getIntensity(for: date)
                                    )
                                    .frame(width: squareSize, height: squareSize)
                                } else {
                                    Color.clear
                                        .frame(width: squareSize, height: squareSize)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .defaultScrollAnchor(.trailing) // 默认滚动到最右边（最新日期）
            
            // Legend
            HStack(spacing: 4) {
                Spacer()
                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Group {
                    Color.secondary.opacity(0.1) // 0
                    Color.blue.opacity(0.3)      // 1
                    Color.blue.opacity(0.5)      // 2
                    Color.blue.opacity(0.7)      // 3
                    Color.blue                   // 4
                }
                .frame(width: 8, height: 8)
                .cornerRadius(1)
                
                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func getIntensity(for date: Date) -> Int {
        let key = Self.dateFormatter.string(from: date)
        return intensityMap[key] ?? 0
    }
    
    // MARK: - Subviews
    
    struct DaySquare: View {
        let date: Date
        let intensity: Int
        
        var color: Color {
            switch intensity {
            case 0: return Color.secondary.opacity(0.1)
            case 1: return Color.blue.opacity(0.3)
            case 2: return Color.blue.opacity(0.5)
            case 3: return Color.blue.opacity(0.7)
            case 4: return Color.blue
            default: return Color.secondary.opacity(0.1)
            }
        }
        
        var body: some View {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
        }
    }
}

#Preview {
    let mockSessions: [DailySession] = [
        DailySession(date: "2026-02-12", fragments: [
            RawFragment(content: "Test", timestamp: 0, type: .text),
            RawFragment(content: "Test", timestamp: 0, type: .text),
            RawFragment(content: "Test", timestamp: 0, type: .text)
        ]), // Intensity 2
        DailySession(date: "2026-02-10", fragments: [
            RawFragment(content: "Test", timestamp: 0, type: .text)
        ]) // Intensity 1
    ]
    
    return CalendarHeatmapView(sessions: mockSessions)
        .padding()
}
