---
description: 创建新的核心 Service (Actor) 或状态管理器，并集成并发安全、数据持久化与测试
---

此 Workflow 总结了 Phase 3-6 的最佳实践，涵盖 Swift 6 并发模型、SwiftData 数据流以及测试注入。

## 1. 架构选型：Actor vs Observable vs MainActor Class

在创建服务前，先明确角色：

| 类型 | 适用场景 | 示例 |
|------|----------|------|
| `actor` | 后台任务、网络请求、数据处理 | `AIService`, `ImageCompressor` |
| `@Observable class` | UI 状态绑定、导航状态 | `NavigationManager` |
| `@MainActor class` | **需要直接操作 SwiftData ModelContext** | `JournalSynthesisService`, `SettingsManager` |

> [!IMPORTANT]
> **Phase 6 经验**：如果 Service 需要频繁与 `ModelContext` 或 `@Model` 类型交互，使用 `@MainActor class` 而非 `actor`，避免跨隔离边界的复杂性。

---

## 2. 定义 Service

### 2.1 Actor (后台服务)

```swift
actor [ServiceName] {
    static let shared = [ServiceName]()
    
    // 后台逻辑方法
    func performTask() async throws -> Result {
        // heavy work
    }
    
    // UIKit 相关方法
    @MainActor
    func processImage(_ image: UIImage) -> UIImage {
        // UIKit calls
    }
    
    // JSONDecoder 等非隔离操作
    nonisolated private func parseJSON(_ data: Data) -> MyModel? {
        try? JSONDecoder().decode(MyModel.self, from: data)
    }
}
```

### 2.2 MainActor Class (数据服务)

```swift
@MainActor
final class [ServiceName] {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func performOperation(
        progressCallback: @escaping (Progress) -> Void
    ) async throws {
        progressCallback(.started)
        
        // 操作 SwiftData 模型
        let entry = MyModel(...)
        modelContext.insert(entry)
        try modelContext.save()  // ⚠️ 必须显式保存
        
        progressCallback(.completed)
    }
}
```

---

## 3. Swift 6 并发安全

### 3.1 Sendable 协议

跨 actor 边界传递的类型**必须**遵循 `Sendable`：

```swift
struct MyOutput: Codable, Sendable {
    let title: String
    let content: String
    
    // 显式实现避免自动合成的隔离问题
    nonisolated init(title: String, content: String) {
        self.title = title
        self.content = content
    }
}

enum MyProgress: Sendable {
    case started
    case processing(percent: Int)
    case completed
}

enum MyError: Error, Sendable {
    case invalidInput
    case networkError(String)
}
```

### 3.2 nonisolated 方法

在 actor 中使用 `JSONDecoder` 等非隔离操作时：

```swift
actor AIService {
    // ⚠️ JSONDecoder().decode() 在 actor 内会触发警告
    // 解决方案：标记为 nonisolated
    nonisolated private func parseOutput(_ raw: String) -> MyOutput {
        guard let data = raw.data(using: .utf8),
              let output = try? JSONDecoder().decode(MyOutput.self, from: data) else {
            return MyOutput.fallback(rawContent: raw)
        }
        return output
    }
}
```

---

## 4. 数据持久化

### 4.1 显式保存

**Phase 6 教训**：`context.insert()` 不会自动持久化！

```swift
func addItem(_ item: MyModel, context: ModelContext) {
    context.insert(item)
    try? context.save()  // ⚠️ 必须显式调用
}
```

### 4.2 数据清洗

```swift
func fetchData(context: ModelContext) -> [MyModel] {
    let descriptor = FetchDescriptor<MyModel>(
        sortBy: [SortDescriptor(\.timestamp)]
    )
    let data = (try? context.fetch(descriptor)) ?? []
    // 去重 + 排序
    return Array(Set(data)).sorted { $0.timestamp < $1.timestamp }
}
```

---

## 5. Fallback 机制

**Phase 6 经验**：服务层必须提供容错逻辑，绝不丢失用户数据。

```swift
struct MyOutput: Sendable {
    // ...字段...
    
    /// Fallback: 解析失败时的默认值
    nonisolated static func fallback(rawContent: String) -> MyOutput {
        return MyOutput(
            title: "无题",
            content: rawContent
        )
    }
}

// 使用
func processResponse(_ raw: String) -> MyOutput {
    guard let parsed = tryParse(raw) else {
        print("⚠️ 解析失败，使用 Fallback")
        return MyOutput.fallback(rawContent: raw)
    }
    return parsed
}
```

---

## 6. Progress 回调模式

长时间操作应提供进度回调：

```swift
enum SynthesisProgress: Sendable {
    case started
    case generating
    case saving
    case completed(id: UUID)
    case failed(Error)
    
    var message: String {
        switch self {
        case .started: return "正在准备..."
        case .generating: return "正在生成..."
        case .saving: return "正在保存..."
        case .completed: return "完成 ✨"
        case .failed: return "失败"
        }
    }
}

func synthesize(
    progressCallback: @escaping (SynthesisProgress) -> Void
) async throws {
    progressCallback(.started)
    // ...
    progressCallback(.generating)
    // ...
    progressCallback(.saving)
    // ...
    progressCallback(.completed(id: resultId))
}
```

---

## 7. 测试

### 7.1 单元测试

```swift
@Test func testFallbackMechanism() async {
    let invalidJSON = "not valid json"
    let output = MyOutput.fallback(rawContent: invalidJSON)
    
    #expect(output.title == "无题")
    #expect(output.content == invalidJSON)
}
```

### 7.2 TestDataInjector

```swift
func injectTestData(context: ModelContext) async {
    // 检查是否已有数据，避免重复注入
    let count = (try? context.fetchCount(FetchDescriptor<MyModel>())) ?? 0
    guard count == 0 else { return }
    
    // 注入测试数据
    // ...
    try? context.save()
}
```

---

## 8. Checklist

- [ ] 选择架构：`actor` / `@Observable` / `@MainActor class`
- [ ] 跨边界类型添加 `Sendable` 协议
- [ ] JSONDecoder 等操作标记 `nonisolated`
- [ ] 数据操作后调用 `context.save()`
- [ ] 实现 Fallback 容错逻辑
- [ ] 长时间操作提供 Progress 回调
- [ ] 更新 `TestDataInjector`（检查重复注入）
- [ ] 编写单元测试
