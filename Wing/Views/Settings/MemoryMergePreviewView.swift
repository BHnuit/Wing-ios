//
//  MemoryMergePreviewView.swift
//  Wing
//
//  Created on 2026-02-05.
//

import SwiftUI
import SwiftData
import os

struct MemoryMergePreviewView: View {
    private static let logger = Logger(subsystem: "wing", category: "MemoryMerge")
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [MergeCandidateGroup] = []
    @State private var isLoading = true
    
    @Binding var memoryType: MemoryType
    
    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ProgressView(L("settings.memory.merge.analyzing"))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else if candidates.isEmpty {
                    EmptyStateView(
                        systemImage: "checkmark.circle",
                        title: L("settings.memory.merge.noSimilar"),
                        description: L("settings.memory.merge.noSimilar.desc")
                    )
                    .listRowBackground(Color.clear)
                    .frame(height: 200)
                } else {
                    ForEach(candidates) { group in
                        MergeGroupSection(group: group) { keepingId, discardingIds in
                            Task {
                                await merge(keeping: keepingId, discarding: discardingIds, group: group)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L("settings.memory.merge.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("settings.memory.merge.close")) { dismiss() }
                }
            }
            .task {
                await analyze()
            }
        }
    }
    
    private func analyze() async {
        isLoading = true
        try? await Task.sleep(for: .seconds(0.5))
        
        guard let context = SettingsManager.shared.modelContext else {
             Self.logger.error("ModelContext not initialized")
             isLoading = false
             return
        }
        let appContainer = context.container
        let service = MemoryService(container: appContainer)
        
        do {
            self.candidates = try await service.findMergeCandidates(type: memoryType)
        } catch {
            Self.logger.error("Check failed: \(error)")
        }
        isLoading = false
    }
    
    private func merge(keeping keepingId: UUID, discarding discardingIds: [UUID], group: MergeCandidateGroup) async {
        guard let context = SettingsManager.shared.modelContext else { return }
        let appContainer = context.container
        let service = MemoryService(container: appContainer)
        
        do {
            try await service.mergeMemories(keepingId: keepingId, discardingIds: discardingIds, type: memoryType)
            withAnimation {
                candidates.removeAll(where: { $0.id == group.id })
            }
        } catch {
            Self.logger.error("Merge failed: \(error)")
        }
    }
}

struct MergeGroupSection: View {
    let group: MergeCandidateGroup
    let onMerge: (UUID, [UUID]) -> Void
    
    @State private var selectedId: UUID?
    
    @Query private var semanticMemories: [SemanticMemory]
    @Query private var episodicMemories: [EpisodicMemory]
    @Query private var proceduralMemories: [ProceduralMemory]
    
    init(group: MergeCandidateGroup, onMerge: @escaping (UUID, [UUID]) -> Void) {
        self.group = group
        self.onMerge = onMerge
        _selectedId = State(initialValue: group.memoryIds.first)
        
        let ids = group.memoryIds
        _semanticMemories = Query(filter: #Predicate<SemanticMemory> { ids.contains($0.id) })
        _episodicMemories = Query(filter: #Predicate<EpisodicMemory> { ids.contains($0.id) })
        _proceduralMemories = Query(filter: #Predicate<ProceduralMemory> { ids.contains($0.id) })
    }
    
    var body: some View {
        Section {
            ForEach(group.memoryIds, id: \.self) { id in
                HStack {
                    Image(systemName: selectedId == id ? "circle.inset.filled" : "circle")
                        .foregroundStyle(selectedId == id ? .blue : .gray)
                        .onTapGesture { selectedId = id }
                    
                    VStack(alignment: .leading) {
                        contentView(for: id)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedId = id }
                }
            }
            
            Button {
                if let keeper = selectedId {
                    let discards = group.memoryIds.filter { $0 != keeper }
                    onMerge(keeper, discards)
                }
            } label: {
                Text(L("settings.memory.merge.keepSelected"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedId == nil)
        } header: {
            Text(String(format: L("settings.memory.merge.suggestMerge"), group.groupKey))
        }
    }
    
    @ViewBuilder
    private func contentView(for id: UUID) -> some View {
        if group.type == .semantic, let item = semanticMemories.first(where: { $0.id == id }) {
            Text(item.value)
                .font(.body)
            Text(String(format: L("settings.memory.merge.confidence"), String(format: "%.2f", item.confidence)))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if group.type == .episodic, let item = episodicMemories.first(where: { $0.id == id }) {
            Text(item.event)
                .font(.body)
            if let emotion = item.emotion {
                Text(emotion).font(.caption).foregroundStyle(.secondary)
            }
        } else if group.type == .procedural, let item = proceduralMemories.first(where: { $0.id == id }) {
            Text(item.pattern)
            Text(item.preference)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(String(format: L("settings.memory.merge.frequency"), item.frequency))
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else {
            Text("Loading...")
        }
    }
}
