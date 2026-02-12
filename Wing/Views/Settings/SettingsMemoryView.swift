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
            Picker(L("settings.memory.type"), selection: $selectedTab) {
                Text(L("settings.memory.semantic")).tag(MemoryType.semantic)
                Text(L("settings.memory.episodic")).tag(MemoryType.episodic)
                Text(L("settings.memory.procedural")).tag(MemoryType.procedural)
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
        .navigationTitle(L("settings.memory.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task { await debugExtractFromLastJournal() }
                    } label: {
                        Label(L("settings.memory.extractLatest"), systemImage: "sparkles")
                    }
                    
                    Button {
                        showJournalPicker = true
                    } label: {
                        Label(L("settings.memory.extractFrom"), systemImage: "doc.text.magnifyingglass")
                    }
                    
                    Button {
                        showMergeSheet = true
                    } label: {
                        Label(L("settings.memory.merge"), systemImage: "arrow.triangle.merge")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label(L("settings.memory.clearAll"), systemImage: "trash")
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
                ProgressView(L("settings.memory.extracting"))
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(8)
            }
        }
        .alert(L("settings.memory.clear.confirm"), isPresented: $showClearConfirmation) {
            Button(L("common.cancel"), role: .cancel) { }
            Button(L("settings.memory.clear.action"), role: .destructive) {
                Task { await clearAllMemories() }
            }
        } message: {
            Text(L("settings.memory.clear.message"))
        }
        .alert(L("settings.memory.error"), isPresented: $showErrorAlert) {
            Button(L("common.ok"), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Subviews
    
    private var semanticList: some View {
        Section {
            if semanticMemories.isEmpty {
                 ContentUnavailableView(L("settings.memory.semantic.empty"), systemImage: "brain", description: Text(L("settings.memory.semantic.empty.desc")))
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
                        Button(L("settings.memory.edit")) {
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
            Text(String(format: L("settings.memory.semantic.count"), semanticMemories.count))
        }
    }
    
    private var episodicList: some View {
        Section {
            if episodicMemories.isEmpty {
                ContentUnavailableView(L("settings.memory.episodic.empty"), systemImage: "clock.arrow.circlepath", description: Text(L("settings.memory.episodic.empty.desc")))
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
                        Button(L("settings.memory.edit")) {
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
            Text(String(format: L("settings.memory.episodic.count"), episodicMemories.count))
        }
    }
    
    private var proceduralList: some View {
        Section {
            if proceduralMemories.isEmpty {
                 ContentUnavailableView(L("settings.memory.procedural.empty"), systemImage: "figure.walk", description: Text(L("settings.memory.procedural.empty.desc")))
            } else {
                ForEach(proceduralMemories) { memory in
                    VStack(alignment: .leading) {
                        Text(memory.pattern)
                            .font(.headline)
                        
                        Text(String(format: L("settings.memory.preference.label"), memory.preference))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            if let trigger = memory.trigger {
                                Text(String(format: L("settings.memory.trigger.label"), trigger))
                            }
                            Spacer()
                            Text(String(format: L("settings.memory.frequency.label"), memory.frequency))
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
                        Button(L("settings.memory.edit")) {
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
            Text(String(format: L("settings.memory.procedural.count"), proceduralMemories.count))
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
            .navigationTitle(L("settings.memory.pickJournal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { showJournalPicker = false }
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
                errorMessage = String(format: L("settings.memory.fetchError"), error.localizedDescription)
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
                errorMessage = String(format: L("settings.memory.extractError"), error.localizedDescription)
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
                Section(L("settings.memory.edit.fact")) {
                    TextField(L("settings.memory.edit.key"), text: $memory.key)
                    TextField(L("settings.memory.edit.value"), text: $memory.value)
                }
                
                Section(L("settings.memory.edit.confidence")) {
                    Slider(value: $memory.confidence, in: 0...1) {
                        Text(L("settings.memory.edit.confidence"))
                    }
                    Text(String(format: "%.2f", memory.confidence))
                }
            }
            .navigationTitle(L("settings.memory.edit.semantic"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.done")) { dismiss() }
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
                Section(L("settings.memory.edit.event")) {
                    TextField(L("settings.memory.edit.date"), text: $memory.date)
                    TextField(L("settings.memory.edit.eventDesc"), text: $memory.event, axis: .vertical)
                }
                
                Section(L("settings.memory.edit.detail")) {
                    TextField(L("settings.memory.edit.emotion"), text: Binding(
                        get: { memory.emotion ?? "" },
                        set: { memory.emotion = $0.isEmpty ? nil : $0 }
                    ))
                    TextField(L("settings.memory.edit.context"), text: Binding(
                        get: { memory.context ?? "" },
                        set: { memory.context = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                }
            }
            .navigationTitle(L("settings.memory.edit.episodic"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.done")) { dismiss() }
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
                Section(L("settings.memory.edit.pattern")) {
                    TextField(L("settings.memory.edit.behaviorPattern"), text: $memory.pattern)
                    TextField(L("settings.memory.edit.preference"), text: $memory.preference, axis: .vertical)
                }
                
                Section(L("settings.memory.edit.attribute")) {
                    TextField(L("settings.memory.edit.trigger"), text: Binding(
                        get: { memory.trigger ?? "" },
                        set: { memory.trigger = $0.isEmpty ? nil : $0 }
                    ))
                    Stepper(String(format: L("settings.memory.edit.frequency"), memory.frequency), value: $memory.frequency)
                }
            }
            .navigationTitle(L("settings.memory.edit.procedural"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.done")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
