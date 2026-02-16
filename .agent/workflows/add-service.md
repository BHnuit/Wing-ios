---
description: 创建新的核心 Service (Actor) 或状态管理器，并集成并发安全、数据持久化与测试
---



## 0. 方案调研 (Discovery)

在编写任何代码之前，**必须** 检查 ShipSwift 库中是否已有现成的 Service 或 Manager 实现。

*   **检索命令**: `shipswift searchRecipes` (例如: "auth", "storekit", "camera")
*   **评估**: 检查配方是否符合项目需求（如 `AIService`, `SettingsManager` 等由于业务特殊性通常需手写，但通用功能如 `Auth`, `IAP` 优先复用）。

---

## 1. 架构选型：Actor vs Observable vs MainActor Class

在创建服务前，先明确角色：

| 类型 | 适用场景 | 示例 |
|------|----------|------|
| `actor` | 后台任务、网络请求、纯计算逻辑、**数据导出(无状态)** | `AIService`, `DataExportService` |
| `@Observable class` | UI 状态绑定、导航状态 | `NavigationManager`, `SettingsManager` |
| `@MainActor class` | **操作 SwiftData 写入**、复杂业务流程控制 | `JournalSynthesisService` |

> [!IMPORTANT]
> **Phase 7 经验**：
> *   **工具类服务** (如 `DataExportService`)：优先设计为单例 `actor` 或 `final class` (若无状态)，通过方法参数传递 `ModelContext`。
> *   **数据查询**：在 Service 内部使用 `FetchDescriptor` 直接查询，**不要依赖 View 层的 `@Query` 传递数据**，以确保数据完整性（例如导出功能应包含所有历史数据，而不仅仅是 View 当前展示的数据）。

---

## 2. 定义 Service

### 2.1 Actor (无状态/后台服务)

适用于不需要维护复杂状态，仅执行任务的组件。

```swift
actor [ServiceName] {
    static let shared = [ServiceName]()
    
    // 示例：数据导出 (接受 Context)
    func exportData(context: ModelContext) async throws -> URL {
        // 1. 在 Actor 内部不能直接使用 Context (它是 MainActor 绑定的)
        // 2. 需在 Task.detached 或 MainActor.run 中处理，或者仅使用 Context 读取数据并传递给后续逻辑
        // ⚠️ Phase 7 最佳实践：
        // 对于只读操作，直接在 MainActor 方法中获取数据，传给 Actor 处理；
        // 或者将 export 定义为 @MainActor 方法（如果它不需要后台并发）。
    }
    
    // 推荐：将纯逻辑（如 JSON 编码、文件写入）放在 Actor 中
    nonisolated func saveToFile(data: Data, filename: String) throws -> URL {
        // ...
    }
}
```

### 2.2 MainActor Class (数据/状态服务)

适用于需要与 `ModelContext` 强交互或管理 UI 状态的服务。

```swift
@MainActor
final class [ServiceName]: ObservableObject { // 或 @Observable
    static let shared = [ServiceName]() // 如果是全局单例
    
    func performOperation(context: ModelContext) async throws {
        // 直接操作 Context
        let item = MyModel(...)
        context.insert(item)
        try context.save()
    }
}
```

---

## 3. UI集成与交互 (Phase 7 重点)

### 3.1 避免竞态条件 (Race Conditions)
**问题**：`sheet(isPresented: $show)` 触发时，数据可能还没准备好（异步生成中）。
**解决**：使用 **状态驱动** 的弹窗机制 `sheet(item:)`。

```swift
// ✅ 推荐模式
struct MyView: View {
    @State private var exportItem: ExportItem? // 遵循 Identifiable
    
    var body: some View {
        Button("导出") {
            Task {
                let url = await Service.shared.generate()
                // 数据就绪后赋值，自动触发弹窗
                self.exportItem = ExportItem(url: url)
            }
        }
        .sheet(item: $exportItem) { item in
            ShareSheet(url: item.url)
        }
    }
}
```

### 3.2 设置页集成
若服务需要配置入口：
1.  在 `SettingsEntryView` 创建新的 Section 组件（如 `DataManagementSection`）。
2.  组件内维持独立 State，不要污染主 View。
3.  操作较重时（如大量数据导出），提供 Loading 状态或 Toast 反馈。

---

## 4. SwiftData 数据流最佳实践

### 4.1 全量数据获取 (Export/Backup)
**不要**依赖 `@Query` 属性包装器来做全量导出，因为它可能受到 View 过滤条件的影响。
**应该**使用 `FetchDescriptor` 直接查询。

```swift
// ✅ 推荐：直接查询确保完整性
func exportAll(context: ModelContext) throws {
    let descriptor = FetchDescriptor<WingEntry>(sortBy: [SortDescriptor(\.createdAt)])
    let allEntries = try context.fetch(descriptor)
    // 处理 allEntries (包含 Orphaned 条目)
}
```

### 4.2 级联删除与孤儿数据
*   **级联删除**: 确保 `@Relationship(deleteRule: .cascade)`配置正确。
*   **孤儿数据 (Orphans)**: 业务逻辑应考虑到 `relation` 为 `nil` 的情况（如 `entry.dailySession == nil`）。导出或展示时应有 Fallback 逻辑，避免崩溃。

---

## 5. 测试与验证 (Testing & Verification)

### 5.1 单元测试 (Swift Testing)
使用 `@Test` 宏编写逻辑测试，并利用 Xcode MCP 运行。

```swift
@Test func testExportLogic() async throws {
    let service = DataExportService()
    let entry = WingEntry(...)
    let url = try await service.exportMarkdown(for: entry)
    #expect(FileManager.default.fileExists(atPath: url.path))
}
```

### 5.2 构建与运行验证 (Xcode MCP)
在提交前，务必使用 Agent 工具验证代码的正确性：

1.  **构建项目**: 调用 `mcp_xcode_BuildProject` 确保无编译错误。
2.  **运行测试**: 调用 `mcp_xcode_RunSomeTests` 运行相关的 Suite 或特定测试用例。
    *   构建失败 -> `mcp_xcode_GetBuildLog` 分析 -> 修复。

---

## 6. Checklist

- [ ] **调研**: 已检索 ShipSwift 是否有现成方案。

- [ ] **架构**：明确是 `actor` (计算/IO密集) 还是 `@MainActor class` (由于 SwiftData 限制，绝大多数数据操作服务选这个)。
- [ ] **数据源**：服务内部使用 `FetchDescriptor` 自行获取数据，不依赖 View 传参（除非是单条操作）。
- [ ] **UI 交互**：使用 `sheet(item:)` 避免空弹窗 Bug。
- [ ] **容错**：处理 Optional 关系（Orphaned Data），确保导出/显示不崩溃。
- [ ] **集成**：若有配置项，集成到 `SettingsEntryView`；若有操作，集成到对应详情页 Toolbar。
- [ ] **测试**：编写基础逻辑测试。
- [ ] **验证**: 通过 `mcp_xcode_BuildProject` 和 `mcp_xcode_RunSomeTests` 验证通过。