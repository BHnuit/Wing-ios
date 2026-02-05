//
//  MemoryMergePreviewView.swift
//  Wing
//
//  Created on 2026-02-05.
//

import SwiftUI
import SwiftData

struct MemoryMergePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [MergeCandidateGroup] = []
    @State private var isLoading = true
    
    // 我们需要在这里根据 ID 查询实体详情来显示
    // 但由于 MemoryService 是 actor，我们不能直接传 model 进来，
    // 只能传 ID，然后在 View 里用 @Query 似乎也不行（因为不知道 ID）。
    // 方案：让 View 拥有 ModelContext，根据 ID 动态加载内容。
    // 为了简化，我们让 findMergeCandidates 返回足够的信息供 UI 显示，
    // 或者我们在 View 中 fetch。
    
    // 更好方案：使用 MemoryService 返回的 IDs，在该 View 中使用 lazy fetching.
    // 但为了 UI 响应快，我们创建一个 ViewModel 或者加载所有数据。
    
    @Binding var memoryType: MemoryType
    
    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ProgressView("正在分析...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else if candidates.isEmpty {
                    ContentUnavailableView("未发现相似记忆", systemImage: "checkmark.circle", description: Text("记忆库整理得井井有条"))
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
            .navigationTitle("记忆合并")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                await analyze()
            }
        }
    }
    
    private func analyze() async {
        isLoading = true
        // 模拟一点延迟，体验更好
        try? await Task.sleep(for: .seconds(0.5))
        
        do {
            let container = try ModelContainer(for: SemanticMemory.self, EpisodicMemory.self, ProceduralMemory.self)
            let _ = MemoryService(container: container)
            // 注意：这里创建了新的 Service 实例，但也意味着新的 Context。
            // 对于查询是没问题的。真正的 Merge 操作需要确保持久化。
            // 更好的方式是使用 App 全局的 container。
            // 暂时假设 @Environment(\.modelContext) 的 container 可用。
        } catch {
            print("Failed to create container")
        }
        
        // 使用 SettingsManager 获取 container
        guard let context = SettingsManager.shared.modelContext else {
             print("ModelContext not initialized")
             isLoading = false
             return
        }
        let appContainer = context.container
        let service = MemoryService(container: appContainer)
        
        do {
            self.candidates = try await service.findMergeCandidates(type: memoryType)
        } catch {
            print("Check failed: \(error)")
        }
        isLoading = false
    }
    
    private func merge(keeping keepingId: UUID, discarding discardingIds: [UUID], group: MergeCandidateGroup) async {
        guard let context = SettingsManager.shared.modelContext else { return }
        let appContainer = context.container
        let service = MemoryService(container: appContainer)
        
        do {
            try await service.mergeMemories(keepingId: keepingId, discardingIds: discardingIds, type: memoryType)
            // 移除已处理的组
            withAnimation {
                candidates.removeAll(where: { $0.id == group.id })
            }
        } catch {
            print("Merge failed: \(error)")
        }
    }
}

struct MergeGroupSection: View {
    let group: MergeCandidateGroup
    let onMerge: (UUID, [UUID]) -> Void
    
    @State private var selectedId: UUID?
    
    // 动态获取记忆详情
    @Query private var semanticMemories: [SemanticMemory]
    @Query private var episodicMemories: [EpisodicMemory]
    @Query private var proceduralMemories: [ProceduralMemory]
    
    init(group: MergeCandidateGroup, onMerge: @escaping (UUID, [UUID]) -> Void) {
        self.group = group
        self.onMerge = onMerge
        // 预选第一个
        _selectedId = State(initialValue: group.memoryIds.first)
        
        // 设置 Query Filter
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
                Text("保留选中项并合并其他")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedId == nil)
        } header: {
            Text("建议合并: \(group.groupKey)")
        }
    }
    
    @ViewBuilder
    private func contentView(for id: UUID) -> some View {
        if group.type == .semantic, let item = semanticMemories.first(where: { $0.id == id }) {
            Text(item.value)
                .font(.body)
            Text("置信度: \(String(format: "%.2f", item.confidence))")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if group.type == .episodic, let item = episodicMemories.first(where: { $0.id == id }) {
            Text(item.event)
                .font(.body)
            if let emotion = item.emotion {
                Text(emotion).font(.caption).foregroundStyle(.secondary)
            }
        } else if group.type == .procedural, let item = proceduralMemories.first(where: { $0.id == id }) {
            Text(item.pattern) // Pattern IS the group key usually, showing preference maybe?
            Text(item.preference)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("频率: \(item.frequency)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else {
            Text("Loading...")
        }
    }
}
