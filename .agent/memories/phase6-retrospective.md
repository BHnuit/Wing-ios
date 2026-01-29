# Phase 6 技术挑战与解决方案总结

> **日期**: 2026-01-30
> **阶段**: Output Flow (日记合成与展示)

---

## 🔥 最大挑战：Swift 6 并发安全 + SwiftData 隔离

### 问题本质
Swift 6 严格的并发安全检查与 SwiftData 的 `@MainActor` 隔离产生冲突。`@Model` 类型和 `ModelContext` 都被隔离到主线程，但我们的服务层需要跨 actor 边界操作它们。

### 具体表现
1. **`JournalSynthesisService` 作为 `actor` 无法直接操作 `ModelContext`**
   - 错误：`Call to main actor-isolated method in actor-isolated context`
   
2. **`JournalOutput` 的 `Decodable` 一致性被隔离到 MainActor**
   - 错误：`main actor-isolated conformance of 'JournalOutput' to 'Decodable' cannot be used in actor-isolated context`

3. **Fallback 静态方法调用初始化器的隔离问题**

### 解决方案

| 问题 | 解决方案 |
|------|----------|
| Service 需要操作 ModelContext | 改用 `@MainActor final class` 而非 `actor` |
| 跨边界传递的类型 | 添加 `Sendable` 协议 |
| Codable 自动合成隔离 | 显式实现 `init(from:)` 并标记 `nonisolated` |
| 初始化器隔离 | 标记 `nonisolated init(...)` |
| JSONDecoder 在 actor 中使用 | 将解析方法标记为 `nonisolated` |

---

## 🐛 隐蔽的持久化 Bug

### 问题
用户消息"吞掉"不显示，退出应用后消息丢失。

### 根因
`SessionService.addTextFragment()` 只调用了 `context.insert()`，**没有调用 `context.save()`**。SwiftData 的 insert 只是内存操作，不会自动持久化。

### 教训
> **永远显式调用 `context.save()`！**

---

## 🎨 Markdown 渲染陷阱

### 问题 1：原始符号显示
`###` 和 `**` 等 Markdown 符号原样显示而非渲染。

**根因**: 使用了 `.inlineOnlyPreservingWhitespace` 选项，只解析内联元素。
**解决**: 改用 `.full` 选项。

### 问题 2：段落合并
所有段落被合并成一大段文字。

**根因**: SwiftUI 的 `AttributedString(markdown:)` 将换行符当作空格处理。
**解决**: 按 `\n\n` 分割为段落数组，逐段渲染。

---

## 📦 测试数据注入的坑

### 问题
测试数据每次启动都会重复注入，导致同一天有多个 Session，用户新消息被添加到"错误"的 Session。

### 解决方案
```swift
// 检查是否已有数据
let count = (try? context.fetchCount(descriptor)) ?? 0
guard count == 0 else { return }
```

并且使用 `container.mainContext` 而非 `Task.detached` 创建新 context，确保数据同步。

---

## 💡 核心体感总结

1. **Swift 6 并发不是"加个 async/await 就完事"**
   - 要理解隔离域（isolation domain）的概念
   - SwiftData 模型天生 MainActor 隔离
   - 跨隔离传递的类型必须 Sendable

2. **SwiftData 不是"自动保存"**
   - insert ≠ 持久化
   - 必须显式 save()

3. **原生 Markdown 渲染有限制**
   - 需要手动处理段落分隔
   - `.full` 选项才能解析块级元素

4. **测试数据注入器要"幂等"**
   - 检查是否已有数据
   - 使用同一个 context

---

## 🔮 下次对话的快速恢复

当处理类似问题时，问自己：

1. **这个类型需要跨 actor 传递吗？** → 加 `Sendable`
2. **这个 Service 需要操作 ModelContext 吗？** → 用 `@MainActor class`
3. **在 actor 中用 JSONDecoder 吗？** → 标记 `nonisolated`
4. **数据操作后要持久化吗？** → 调用 `save()`
5. **这是一个可能失败的操作吗？** → 提供 Fallback
