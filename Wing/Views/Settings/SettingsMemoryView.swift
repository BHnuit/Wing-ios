//
//  SettingsMemoryView.swift
//  Wing
//
//  Created on 2026-02-05.
//

import SwiftUI
import SwiftData

struct SettingsMemoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: MemoryType = .semantic
    @State private var isExtracting: Bool = false
    
    @State private var showMergeSheet: Bool = false
    @State private var showClearConfirmation: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    // Sheet States
    @State private var showJournalPicker: Bool = false
    @State private var showEditSheet: Bool = false
    @State private var editingSemantic: SemanticMemory?
    @State private var editingEpisodic: EpisodicMemory?
    @State private var editingProcedural: ProceduralMemory?
    
    // Queries
    @Query(sort: \SemanticMemory.confidence, order: .reverse) private var semanticMemories: [SemanticMemory]
    @Query(sort: \EpisodicMemory.date, order: .reverse) private var episodicMemories: [EpisodicMemory]
    @Query(sort: \ProceduralMemory.frequency, order: .reverse) private var proceduralMemories: [ProceduralMemory]
    
    // Journal Query for Picker
    @Query(sort: \WingEntry.createdAt, order: .reverse) private var allEntries: [WingEntry]
    
    var body: some View {
        VStack(spacing: 0) {
            // Type Segmented Control
            Picker("记忆类型", selection: $selectedTab) {
                Text("事实").tag(MemoryType.semantic)
                Text("经历").tag(MemoryType.episodic)
                Text("习惯").tag(MemoryType.procedural)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            List {
                switch selectedTab {
                case .semantic:
                    semanticList
                case .episodic:
                    episodicList
                case .procedural:
                    proceduralList
                }
            }
        }
        .navigationTitle("长期记忆")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task { await debugExtractFromLastJournal() }
                    } label: {
                        Label("从最新日记提取", systemImage: "sparkles")
                    }
                    
                    Button {
                        showJournalPicker = true
                    } label: {
                        Label("从指定日记提取...", systemImage: "doc.text.magnifyingglass")
                    }
                    
                    Button {
                        showMergeSheet = true
                    } label: {
                        Label("整理合并相似记忆...", systemImage: "arrow.triangle.merge")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label("清空所有记忆", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showJournalPicker) {
            journalPickerSheet
        }
        .sheet(isPresented: $showMergeSheet) {
            MemoryMergePreviewView(memoryType: $selectedTab)
        }
        .sheet(item: $editingSemantic) { memory in
        // ...
            EditSemanticSheet(memory: memory)
        }
        .sheet(item: $editingEpisodic) { memory in
            EditEpisodicSheet(memory: memory)
        }
        .sheet(item: $editingProcedural) { memory in
            EditProceduralSheet(memory: memory)
        }
        .overlay {
            if isExtracting {
                ProgressView("正在提取记忆...")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(8)
            }
        }
        .alert("确认清空所有记忆？", isPresented: $showClearConfirmation) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                Task { await clearAllMemories() }
            }
        } message: {
            Text("此操作将永久删除所有已提取的事实、经历和习惯记忆。无法撤销。但不会删除您的日记内容。")
        }
        .alert("操作失败", isPresented: $showErrorAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Subviews
    
    private var semanticList: some View {
        Section {
            if semanticMemories.isEmpty {
                 ContentUnavailableView("暂无事实", systemImage: "brain", description: Text("AI 尚未提取到关于您的事实信息"))
            } else {
                ForEach(semanticMemories) { memory in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(memory.key)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(String(format: "%.0f%%", memory.confidence * 100))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                        Text(memory.value)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingSemantic = memory
                    }
                    .swipeActions(edge: .leading) {
                        Button("编辑") {
                            editingSemantic = memory
                        }
                        .tint(.orange)
                    }
                }
                .onDelete { indexSet in
                    deleteItems(at: indexSet, from: semanticMemories)
                }
            }
        } header: {
            Text("共有 \(semanticMemories.count) 条事实")
        }
    }
    
    private var episodicList: some View {
        Section {
            if episodicMemories.isEmpty {
                ContentUnavailableView("暂无经历", systemImage: "clock.arrow.circlepath", description: Text("AI 尚未提取到重要的生活事件"))
            } else {
                ForEach(episodicMemories) { memory in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(memory.date)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                            
                            if let emotion = memory.emotion {
                                Text(emotion)
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            Spacer()
                        }
                        
                        Text(memory.event)
                            .font(.body)
                        
                        if let context = memory.context {
                            Text(context)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingEpisodic = memory
                    }
                    .swipeActions(edge: .leading) {
                        Button("编辑") {
                            editingEpisodic = memory
                        }
                        .tint(.orange)
                    }
                }
                .onDelete { indexSet in
                    deleteItems(at: indexSet, from: episodicMemories)
                }
            }
        } header: {
            Text("共有 \(episodicMemories.count) 个事件")
        }
    }
    
    private var proceduralList: some View {
        Section {
            if proceduralMemories.isEmpty {
                 ContentUnavailableView("暂无习惯", systemImage: "figure.walk", description: Text("AI 尚未发现您的行为模式"))
            } else {
                ForEach(proceduralMemories) { memory in
                    VStack(alignment: .leading) {
                        Text(memory.pattern)
                            .font(.headline)
                        
                        Text("偏好: \(memory.preference)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            if let trigger = memory.trigger {
                                Text("触发: \(trigger)")
                            }
                            Spacer()
                            Text("出现 \(memory.frequency) 次")
                                .fontWeight(.bold)
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingProcedural = memory
                    }
                    .swipeActions(edge: .leading) {
                        Button("编辑") {
                            editingProcedural = memory
                        }
                        .tint(.orange)
                    }
                }
                .onDelete { indexSet in
                    deleteItems(at: indexSet, from: proceduralMemories)
                }
            }
        } header: {
            Text("共有 \(proceduralMemories.count) 个模式")
        }
    }
    
    private var journalPickerSheet: some View {
        NavigationStack {
            List(allEntries) { entry in
                Button {
                    showJournalPicker = false
                    Task {
                        await extractFromJournal(id: entry.id)
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text(entry.title)
                            .font(.headline)
                        Text(entry.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(Date(timeIntervalSince1970: TimeInterval(entry.createdAt) / 1000).formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle("选择日记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showJournalPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Actions
    
    private func deleteItems<T: PersistentModel>(at offsets: IndexSet, from items: [T]) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
    
    private func debugExtractFromLastJournal() async {
        isExtracting = true
        defer { isExtracting = false }
        
        // 1. Fetch last session
        var descriptor = FetchDescriptor<DailySession>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        
        do {
            guard let session = try modelContext.fetch(descriptor).first,
                  let entry = session.finalEntry else {
                print("No journal found")
                return
            }
            
            // 2. Extract
            await extractFromJournal(id: entry.id)
        } catch {
            print("Extraction failed: \(error)")
            await MainActor.run {
                errorMessage = "无法查找最近日记: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }
    
    private func extractFromJournal(id: UUID) async {
        isExtracting = true
        defer { isExtracting = false }
        
        do {
            try await MemoryService(container: modelContext.container).extractMemories(for: id)
            print("Extraction triggered successfully for \(id)")
            
            // Impact Feedback
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            await MainActor.run { generator.impactOccurred() }
        } catch {
            print("Extraction failed: \(error)")
            await MainActor.run {
                errorMessage = "记忆提取失败: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }
    
    private func clearAllMemories() async {
        do {
            // 安全删除：批量删除指定类型的模型数据
            try modelContext.delete(model: SemanticMemory.self)
            try modelContext.delete(model: EpisodicMemory.self)
            try modelContext.delete(model: ProceduralMemory.self)
            
            try modelContext.save()
            print("Memories cleared successfully")
            
            // 触发震动反馈
            let generator = UIImpactFeedbackGenerator(style: .medium)
            await MainActor.run { generator.impactOccurred() }
        } catch {
            print("Clear failed: \(error)")
        }
    }
}

// MARK: - Edit Sheets

struct EditSemanticSheet: View {
    @Bindable var memory: SemanticMemory
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("事实") {
                    TextField("键", text: $memory.key)
                    TextField("值", text: $memory.value)
                }
                
                Section("置信度") {
                    Slider(value: $memory.confidence, in: 0...1) {
                        Text("置信度")
                    }
                    Text(String(format: "%.2f", memory.confidence))
                }
            }
            .navigationTitle("编辑事实")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct EditEpisodicSheet: View {
    @Bindable var memory: EpisodicMemory
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("事件") {
                    TextField("日期 (YYYY-MM-DD)", text: $memory.date)
                    TextField("事件描述", text: $memory.event, axis: .vertical)
                }
                
                Section("细节") {
                    TextField("情绪", text: Binding(
                        get: { memory.emotion ?? "" },
                        set: { memory.emotion = $0.isEmpty ? nil : $0 }
                    ))
                    TextField("上下文", text: Binding(
                        get: { memory.context ?? "" },
                        set: { memory.context = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                }
            }
            .navigationTitle("编辑经历")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct EditProceduralSheet: View {
    @Bindable var memory: ProceduralMemory
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("模式") {
                    TextField("行为模式", text: $memory.pattern)
                    TextField("偏好", text: $memory.preference, axis: .vertical)
                }
                
                Section("属性") {
                    TextField("触发条件", text: Binding(
                        get: { memory.trigger ?? "" },
                        set: { memory.trigger = $0.isEmpty ? nil : $0 }
                    ))
                    Stepper("出现频率: \(memory.frequency)", value: $memory.frequency)
                }
            }
            .navigationTitle("编辑习惯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

