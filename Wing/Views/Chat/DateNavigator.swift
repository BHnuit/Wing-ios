//
//  DateNavigator.swift
//  Wing
//
//  Created on 2026-01-29.
//

import SwiftUI

/**
 * 日期导航组件
 *
 * 功能：
 * - 显示当前查看的日期
 * - 左右箭头切换到有记录的日期
 * - 点击日期显示日期选择器（仅有记录的日期可选）
 */
struct DateNavigator: View {
    @Binding var selectedDate: String // YYYY-MM-DD
    let availableDates: [String] // 有记录的日期列表
    
    @State private var showDatePicker = false
    
    var body: some View {
        ZStack {
            // 中间：日期胶囊
            Button {
                showDatePicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(smartDateString)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .glassEffect(.regular, in: Capsule())
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(
                    selectedDate: $selectedDate,
                    availableDates: availableDates
                )
            }
            
            // 两侧：导航按钮
            HStack {
                // 左箭头：前一个日期
                Button {
                    navigateToPrevious()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundStyle(hasPreviousDate ? .primary : .tertiary)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular, in: Circle())
                }
                .disabled(!hasPreviousDate)
                .opacity(hasPreviousDate ? 1 : 0.6)
                
                Spacer()
                
                // 右箭头：后一个日期
                Button {
                    navigateToNext()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundStyle(hasNextDate ? .primary : .tertiary)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular, in: Circle())
                }
                .disabled(!hasNextDate)
                .opacity(hasNextDate ? 1 : 0.6)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16) // Ensure buttons conform to standard margin
    }
    
    // MARK: - Computed Properties
    
    private var smartDateString: String {
        let date = dateFromString(selectedDate)
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return L("date.today")
        } else if calendar.isDateInYesterday(date) {
            return L("date.yesterday")
        } else if isDayBeforeYesterday(date) {
            return "前天" // 增加“前天”的支持
        } else {
            let formatter = DateFormatter()
            // 如果是当年，只显示 M月d日，否则显示 yyyy年M月d日
            if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
                formatter.dateFormat = "M月d日"
            } else {
                formatter.dateFormat = "yyyy年M月d日"
            }
            // 保持原有的语言环境逻辑
            let language = SettingsManager.shared.appSettings?.language ?? .zh
            let localeId: String
            switch language {
            case .system: localeId = Locale.current.identifier
            case .zh: localeId = "zh_CN"
            case .en: localeId = "en_US"
            case .ja: localeId = "ja_JP"
            }
            formatter.locale = Locale(identifier: localeId)
            
            return formatter.string(from: date)
        }
    }
    
    private func isDayBeforeYesterday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()),
              let dayBefore = calendar.date(byAdding: .day, value: -1, to: yesterday) else {
            return false
        }
        return calendar.isDate(date, inSameDayAs: dayBefore)
    }
    
    /// 日期按时间升序排列（旧→新），并去重
    private var sortedDates: [String] {
        Array(Set(availableDates)).sorted()
    }
    
    private var currentIndex: Int? {
        sortedDates.firstIndex(of: selectedDate)
    }
    
    /// 是否有更早的日期（左箭头）
    private var hasPreviousDate: Bool {
        guard let index = currentIndex else { return false }
        return index > 0
    }
    
    /// 是否有更新的日期（右箭头）
    private var hasNextDate: Bool {
        guard let index = currentIndex else { return false }
        return index < sortedDates.count - 1
    }
    
    // MARK: - Actions
    
    /// 跳转到更早的日期
    private func navigateToPrevious() {
        guard let index = currentIndex, index > 0 else { return }
        selectedDate = sortedDates[index - 1]
    }
    
    /// 跳转到更新的日期
    private func navigateToNext() {
        guard let index = currentIndex, index < sortedDates.count - 1 else { return }
        selectedDate = sortedDates[index + 1]
    }
    
    // MARK: - Helper Methods
    
    private func dateFromString(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string) ?? Date()
    }
}

// MARK: - Date Picker Sheet

/**
 * 日期选择器弹窗
 *
 * 使用自定义日历视图，仅显示有记录的日期
 */
private struct DatePickerSheet: View {
    @Binding var selectedDate: String
    let availableDates: [String]
    
    @Environment(\.dismiss) private var dismiss
    @State private var displayMonth: Date = Date()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 月份导航
                monthNavigator
                
                Divider()
                
                // 单月日历视图
                VStack(spacing: 16) {
                    // 星期标题
                    weekdayHeaders
                    
                    // 日期网格
                    calendarGrid
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle(L("date.picker.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("date.picker.done")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            // 初始化显示选中日期所在的月份
            displayMonth = startOfMonth(dateFromString(selectedDate))
        }
    }
    
    // MARK: - Month Navigator
    
    private var monthNavigator: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            
            Spacer()
            
            Text(monthYearString(for: displayMonth))
                .font(.headline)
            
            Spacer()
            
            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(isCurrentMonth ? .gray : .blue)
            }
            .disabled(isCurrentMonth)
        }
        .padding()
    }
    
    // MARK: - Calendar Grid
    
    private var calendarGrid: some View {
        let days = daysInMonth(displayMonth)
        
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day = day {
                    dayCell(for: day)
                } else {
                    Color.clear
                        .frame(height: 40)
                }
            }
        }
    }
    
    private var weekdayHeaders: some View {
        let weekdays = L("date.weekdays").components(separatedBy: ",")
        return HStack(spacing: 0) {
            ForEach(weekdays, id: \.self) { weekday in
                Text(weekday)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func dayCell(for date: Date) -> some View {
        let dateString = stringFromDate(date)
        let isAvailable = availableDates.contains(dateString)
        let isSelected = dateString == selectedDate
        let isFuture = date > Date()
        
        return Button {
            if isAvailable {
                selectedDate = dateString
                dismiss()
            }
        } label: {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.body)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : Color.clear)
                )
                .foregroundColor(
                    isSelected ? .white : (
                        isFuture ? Color.gray.opacity(0.3) : (
                            isAvailable ? .blue : .gray
                        )
                    )
                )
                .overlay(
                    Circle()
                        .stroke(
                            isAvailable && !isSelected ? Color.blue : Color.clear,
                            lineWidth: 2
                        )
                )
        }
        .disabled(!isAvailable || isFuture)
    }
    
    // MARK: - Computed Properties
    
    private var isCurrentMonth: Bool {
        Calendar.current.isDate(displayMonth, equalTo: Date(), toGranularity: .month)
    }
    
    // MARK: - Helper Methods
    
    private func daysInMonth(_ month: Date) -> [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: displayMonth) {
            // 不能超过当前月份
            let today = startOfMonth(Date())
            if newMonth <= today {
                displayMonth = newMonth
            }
        }
    }
    
    private func startOfMonth(_ date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? date
    }
    
    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = L("date.format.yearMonth")
        // Use current app language
        let language = SettingsManager.shared.appSettings?.language ?? .zh
        let localeId: String
        switch language {
        case .system: localeId = Locale.current.identifier
        case .zh: localeId = "zh_CN"
        case .en: localeId = "en_US"
        case .ja: localeId = "ja_JP"
        }
        formatter.locale = Locale(identifier: localeId)
        return formatter.string(from: date)
    }
    
    private func dateFromString(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string) ?? Date()
    }
    
    private func stringFromDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

#Preview {
    @Previewable @State var date = "2026-01-29"
    
    VStack {
        DateNavigator(
            selectedDate: $date,
            availableDates: [
                "2026-01-29",
                "2026-01-28",
                "2026-01-22",
                "2026-01-15"
            ]
        )
        Text("Selected: \(date)")
            .font(.caption)
            .foregroundStyle(.secondary)
        Spacer()
    }
}
