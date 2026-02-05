# Phase 8 Retrospective: The Agent & The Brain

**Created**: 2026-02-05
**Focus**: AI Memory Service, Swift Concurrency, Algorithms
**Status**: Completed

In Phase 8, we successfully implemented the "Long-Term Memory" system, transforming Wing from a simple diary into an agentic companion that remembers facts, events, and user habits. This phase was technically dense, involving Actor isolation, custom algorithms, and complex state management.

## 1. 核心挑战与解决方案 (Core Challenges & Solutions)

### 1.1 SwiftData 与 Actor 的并发隔离 (The Actor Isolation Dilemma)
**挑战**：
`MemoryService` 被设计为 `actor` 以确保后台线程安全。然而，SwiftData 的 `ModelContext` 默认并未完全线程安全，且通常绑定于 `MainActor` (view context)。直接在后台 Actor 中使用 UI 层的 Context 会导致 "MainActor-isolated property 'modelContext' can not be referenced from a non-isolated context" 或运行时崩溃。

**解决方案**：
*   **独立的 Context**：`MemoryService` 初始化时接受 `ModelContainer`，并内部创建独立的 `ModelContext(container)`。
    ```swift
    init(container: ModelContainer) {
        self.modelContext = ModelContext(container) // 独立的非 UI contex
        self.modelContext.autosaveEnabled = false   // 手动控制事务
    }
    ```
*   **非隔离工具函数**：将 `Levenshtein` 等纯算法扩展声明为 `nonisolated`，避免不必要的 Actor 调度开销。

### 1.2 记忆去重与模糊匹配 (The Duplicate Problem)
**挑战**：
AI 提取的记忆往往只有细微差别（如“喜欢吃苹果” vs “爱吃苹果”）。完全匹配无法识别这些重复项，导致数据库膨胀。Swift 标准库缺乏现成的字符串相似度算法。

**解决方案**：
*   **手写 Levenshtein 算法**：实现经典的编辑距离算法，并归一化为 0.0-1.0 的相似度分数。
*   **多策略阈值**：
    *   **语义 (Semantic)**: 严格 Key 匹配。
    *   **情景 (Episodic)**: 宽松文本相似度 (>0.45) + 同日期。
    *   **程序性 (Procedural)**: 中等相似度 (>0.55) + Key Pattern。
*   **合并 UI**：与其让后端“黑盒”自动合并，不如提供 `MemoryMergePreviewView`，让用户拥有最终决定权，既安全又增强了用户的掌控感。

### 1.3 提取失败的用户反馈 (The Silent Failure)
**挑战**：
由于 LLM 调用和网络请求的不确定性，提取可能失败。初期设计中，失败仅在控制台打印日志，用户感知为“点击了没反应”。

**解决方案**：
*   **显式状态管理**：引入 `@State private var errorMessage` 和 `showErrorAlert`。
*   **MainActor 调度**：在 Actor 的 `catch` 块中，必须通过 `await MainActor.run` 切回主线程更新 UI 状态，确保 Alert 正确弹出。

## 2. 最佳实践总结 (Key Takeaways)

1.  **Actor + SwiftData 模式**：对于后台数据任务，永远传入 `ModelContainer` 而非 `ModelContext`。让 Service 拥有自己的 Context 是并发安全的基石。
2.  **算法本地化**：对于简单的文本相似度，本地实现 Levenshtein 比调用 LLM 判断要快得多且零成本。不要事事都依赖 AI。
3.  **用户决策优先**：对于“合并”这种破坏性操作（Destructive Action），提供预览（Preview）和确认（Confirmation）比完美的自动化算法更重要。

## 3. 下一步建议 (Phase 9 Preview)

Phase 8 让 Wing 有了“脑子”。Phase 9 将赋予它更精致的“外表”和更强的“感知能力”：
*   **数据可视化**：利用 Phase 8 积累的数据，通过 Heatmap 和 Charts 展示用户的活动趋势。
*   **视觉打磨**：引入高级字体和排版设置，匹配我们在 Phase 6 建立的 Markdown 渲染能力。
*   **数据掌控**：完善导入功能，让用户的数据管理闭环（Import/Export/Clear）。
