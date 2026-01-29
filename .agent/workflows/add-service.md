---
description: 创建新的核心 Service (Actor) 或状态管理器，并集成并发安全、数据持久化与测试
---

此 Workflow 总结了 Phase 3-5 的最佳实践，涵盖 Swift 6 并发模型、SwiftData 数据流以及测试注入。

## 1. 架构选型：Actor vs Observable

在创建服务前，先明确角色：

*   **Logic Service (`actor`)**: 负责耗时任务、数据处理、IO 操作（如 `AIService`, `ImageCompressor`, `SessionService`）。**默认选择**。
*   **State Manager (`@Observable class`)**: 负责 UI 状态绑定、导航状态（如 `NavigationManager`, `SettingsManager`）。运行在 `@MainActor`。

---

## 2. 定义 Service (Actor)

在 `Wing/Services` 目录下创建。

**Swift 6 并发规则**：
*   **后台逻辑**：默认在 actor 内部运行。
*   **UI 依赖**：如果涉及 `UIImage`、`UIKit` 或 `SwiftUI` 更新，**必须**标记 `@MainActor` 方法或使用 `MainActor.run`。

```swift
import Foundation
import UIKit // 如果涉及图片处理

actor [ServiceName] {
    // 推荐提供 shared 单例，但保留 init 以便测试注入
    static let shared = [ServiceName]()
    private init() {}

    // 示例：纯逻辑方法（后台线程）
    func performCalculation() async -> Data {
        // ... heavy work
    }

    // 示例：UI 相关方法（必须在主线程）
    // 典型案例：ImageCompressor.compress 调用 UIImage 操作
    @MainActor
    func processImage(_ image: UIImage) -> UIImage {
        // UIKit calls
        return image
    }
    
    // 示例：跨 Actor 调用
    func complexTask() async {
        let data = await performCalculation()
        // 跳回主线程处理 UI 数据
        let image = await MainActor.run { UIImage(data: data) }
    }
}
```

---

## 3. 集成 SwiftData (如涉及数据)

**规则**：
*   **Context 传递**：Actor 不持久持有 `ModelContext`，而是通过方法参数传递（`context: ModelContext`）。
*   **数据清洗（重要）**：
    *   **不要信任**原始数据源的纯净度。
    *   在查询或返回给 UI 前，务必进行**去重** (`Set`) 和**排序** (`sorted`)。
    *   *教训来源：Phase 5 DateNavigator 重复日期导致的一系列 Bug。*

```swift
func fetchData(context: ModelContext) throws -> [MyModel] {
    let descriptor = FetchDescriptor<MyModel>(sortBy: [SortDescriptor(\.timestamp)])
    let data = try context.fetch(descriptor)
    // 建议：数据层做防御性清洗
    return deduplicate(data)
}
```

---

## 4. 集成 Keychain (如涉及敏感信息)

**规则**：
*   **严禁**明文存储 API Key 或 Token。
*   使用 `KeychainHelper.shared`。

```swift
private let keychain = KeychainHelper.shared
func saveSecret(_ secret: String) async {
    try? await keychain.save(secret, for: "service_key")
}
```

---

## 5. 测试驱动开发 (TDD) & 注入

**步骤**：

1.  **写单元测试** (`WingTests`):
    *   使用 `Swift Testing` (@Test)。
    *   测试并发逻辑和数据边界。

2.  **更新测试数据注入器** (`TestDataInjector.swift`):
    *   如果新 Service 引入了新数据模型（如新类型的 `Fragment`），**必须**同步更新 `TestDataInjector`。
    *   确保 `DEBUG` 模式下能自动生成各种边界数据（空状态、极限长文本、重复数据等）以供 UI 验证。

```swift
// TestDataInjector.swift
func injectNewFeatureData(context: ModelContext) async {
    // 注入极端情况数据，方便 UI 手动验证
}
```

---

## 6. 使用 Checklist

- [ ] 决定是 `actor` 还是 `@Observable`
- [ ] 检查是否涉及 UIKit (标记 `@MainActor`)
- [ ] 数据层是否处理了去重和排序
- [ ] 敏感信息是否走了 Keychain
- [ ] 是否更新了 `TestDataInjector`
- [ ] 编写并运行单元测试
