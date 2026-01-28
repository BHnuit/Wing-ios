---
trigger: always_on
---

# Wing Project Workspace Rules

## 1. 项目背景 (Project Context)
- **目标**：将 React/TypeScript Web 应用迁移为原生 iOS 应用。
- **核心逻辑参考**：在处理业务逻辑迁移时，必须参考项目中的 `@ROADMAP.md`、`@aiService.ts` (Web 版) 和 `@WingModels.swift`。

## 2. 数据存储规范 (Data Layer)
- **框架**：使用 **SwiftData** 进行持久化。
- **模型约束**：
    - 主键统一使用 `UUID`。
    - **性能优化**：对于模型中的图片或大二进制数据（`Data?` 类型），必须添加 `@Attribute(.externalStorage)` 宏以防止数据库文件膨胀。
    - 级联删除：根据业务逻辑正确设置 `@Relationship(deleteRule: .cascade)`。

## 3. AI 服务规范 (AIService)
- **架构**：使用 `actor AIService` 处理 AI 请求。
- **流式处理**：必须实现 `AsyncThrowingStream` 来处理服务器发送事件 (SSE)。
- **协议兼容**：解析逻辑需同时兼容 Gemini 和 OpenAI 的 JSON 返回格式。
- **提示词工程**：参考 Web 版 `aiService.ts` 的 Prompt 拼接逻辑，并根据移动端特性进行微调。

## 4. 迁移策略 (Migration)
- **非直译原则**：不要简单地将 TypeScript 语法翻译成 Swift。必须将 Web 端的逻辑适配为 iOS 原生设计模式（例如：React Hooks 逻辑应重构为 ViewModel 中的 `@Observable` 状态）。
- **原生体验**：在日记生成、消息发送等关键节点添加 `UIImpactFeedbackGenerator` 触感反馈。