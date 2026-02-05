//
//  ChatView.swift
//  Wing
//
//  Created on 2026-01-29.
//

import SwiftUI
import SwiftData

/**
 * 聊天记录主视图
 *
 * 功能：
 * - 显示当天的碎片记录
 * - 支持日期切换查看历史
 * - 发送文本和图片消息
 * - 自动滚动到底部
 */
struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationManager.self) private var navigationManager
    @Environment(SettingsManager.self) private var settingsManager
    @Query private var allSessions: [DailySession]
    
    @State private var selectedDate: String
    @State private var inputText = ""
    @State private var sessionService = SessionService()
    
    // 日记合成状态
    @State private var isSynthesizing = false
    @State private var synthesisProgress: SynthesisProgress = .started
    @State private var synthesisError: Error?
    
    // 当前查看的 Session
    private var currentSession: DailySession? {
        allSessions.first { $0.date == selectedDate }
    }
    
    // 碎片列表（按时间排序）
    private var fragments: [RawFragment] {
        currentSession?.fragments.sorted { $0.timestamp < $1.timestamp } ?? []
    }
    
    // 有记录的日期列表 (始终包含今天，确保可导航)
    private var availableDates: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        
        var dates = Set(allSessions.map { $0.date })
        dates.insert(today)
        return Array(dates).sorted()
    }
    
    init() {
        // 初始化为今天
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        _selectedDate = State(initialValue: formatter.string(from: Date()))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部日期导航
                DateNavigator(
                    selectedDate: $selectedDate,
                    availableDates: availableDates
                )
                .padding(.horizontal)
                
                Divider()
                
                // 消息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if fragments.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(Array(fragments.enumerated()), id: \.element.id) { index, fragment in
                                    let nextFragment = index < fragments.count - 1 ? fragments[index + 1] : nil
                                    let showTimestamp = shouldShowTimestamp(
                                        current: fragment,
                                        next: nextFragment
                                    )
                                    
                                    FragmentBubble(
                                        fragment: fragment,
                                        showTimestamp: showTimestamp
                                    )
                                }
                            }
                        }
                        .padding(.top, 8)
                        
                        // 底部锚点
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: fragments.count) { _, _ in
                        // 新消息时滚动到底部
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
            .navigationTitle("当下")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        handleSynthesizeJournal()
                    } label: {
                        Label("生成日记", systemImage: "wand.and.stars")
                    }
                    .disabled(fragments.isEmpty)
                }
            }
            .overlay {
                // 合成进度 UI
                if isSynthesizing {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        SynthesisProgressView(progress: synthesisProgress)
                    }
                }
            }
            .alert("生成失败", isPresented: .constant(synthesisError != nil)) {
                Button("确定") {
                    synthesisError = nil
                }
            } message: {
                if let error = synthesisError {
                    Text(error.localizedDescription)
                }
            }
            .safeAreaInset(edge: .bottom) {
                ChatInputBar(
                    text: $inputText,
                    onSend: handleSendText,
                    onImageSelected: handleImageSelected
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text(isToday ? "新的一天开始了..." : "这一天还没有记录")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("记录此刻的想法、感受或灵感")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Computed Properties
    
    private var isToday: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return selectedDate == formatter.string(from: Date())
    }
    
    // MARK: - Actions
    
    private func handleSendText() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        Task {
            let session = await sessionService.getOrCreateSession(
                for: selectedDate,
                context: modelContext
            )
            
            await sessionService.addTextFragment(
                inputText,
                to: session,
                context: modelContext
            )
            
            // 清空输入
            await MainActor.run {
                inputText = ""
            }
        }
    }
    
    private func handleImageSelected(_ data: Data) async {
        let session = await sessionService.getOrCreateSession(
            for: selectedDate,
            context: modelContext
        )
        
        await sessionService.addImageFragment(
            data,
            to: session,
            context: modelContext
        )
    }
    
    private func handleSynthesizeJournal() {
        guard let session = currentSession else { return }
        
        Task {
            // 获取 AI 配置
            guard let config = await settingsManager.getAIConfig() else {
                synthesisError = SynthesisError.configurationMissing
                return
            }
            
            // 显示进度 UI
            await MainActor.run {
                isSynthesizing = true
                synthesisProgress = .started
            }
            
            do {
                // 获取日记语言设置
                let journalLanguage = settingsManager.appSettings?.journalLanguage ?? .auto
                
                // 调用合成服务
                let entryId = try await JournalSynthesisService.shared.synthesize(
                    session: session,
                    config: config,
                    journalLanguage: journalLanguage,
                    context: modelContext,
                    progressCallback: { progress in
                        synthesisProgress = progress
                    }
                )
                
                // 等待一下让用户看到完成状态
                try await Task.sleep(for: .seconds(1))
                
                // 关闭进度 UI
                await MainActor.run {
                    isSynthesizing = false
                }
                
                // 跳转到日记详情
                await MainActor.run {
                    navigationManager.navigateToJournalDetail(entryId: entryId)
                }
                
            } catch {
                await MainActor.run {
                    isSynthesizing = false
                    synthesisError = error
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /**
     * 判断是否显示时间戳（5分钟内合并）
     */
    private func shouldShowTimestamp(current: RawFragment, next: RawFragment?) -> Bool {
        guard let next = next else { return true }
        let diff = next.timestamp - current.timestamp
        return diff > 5 * 60 * 1000 // 5 分钟（毫秒）
    }
}

#Preview {
    ChatView()
        .modelContainer(for: [
            DailySession.self,
            RawFragment.self,
            WingEntry.self
        ], inMemory: true)
}
