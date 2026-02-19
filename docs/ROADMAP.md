# 🗺️ Wing iOS Native - 开发路线图 (Roadmap)

> **当前状态**: Phase 10 (深度体验打磨) - 进行中
> **目标环境**: iOS 26.2+ | Swift 6.2 | SwiftUI | SwiftData
> **最后更新**: 2026-02-19
> **Xcode**: 26.3

## 📌 项目概述
Wing 是一个从 React/TypeScript 重构为原生 iOS 的 AI 驱动日记应用。
它利用 **SwiftData** 进行本地持久化，使用 **SwiftUI** 构建从零开始的界面，并集成 **LLM (Gemini/OpenAI)** 进行日记智能合成。

---

## 🏗️ 架构规范 (Cursor 指南)

*   **设计模式**: MVVM (Model-View-ViewModel) + Services (基于 Actor)。
*   **并发模型**: 严格使用 `async/await`。使用 `Task` 和 `Actor` 保证线程安全。
*   **本地化**: 使用 `L()` 辅助函数 + `SettingsManager` 实现动态切换。
*   **数据层**:
    *   **SwiftData**: 使用 `@Model` 进行持久化。
    *   **图片处理**: 必须使用 `@Attribute(.externalStorage) var data: Data?` 防止数据库膨胀。
    *   **ID**: 始终使用 `UUID`。
*   **安全性**: API Keys 必须存储在 **Keychain** 中（通过 `KeychainHelper`），严禁存储在 UserDefaults 或代码中。
*   **UI**: 纯 SwiftUI。使用 `NavigationStack` 进行路由管理。
*   **测试**:
    *   `@Test` (Swift Testing) 用于逻辑/模型测试。
    *   `XCTest` 用于 UI/集成测试。

---

## ✅ Phase 1: 环境与初始配置 (已完成)
- [x] **项目初始化**: Xcode 26.2, Swift 6.2.
- [x] **配置**: 建立 iOS 环境下的 `.cursorrules`.
- [x] **Git**: 仓库初始化与清理.

## ✅ Phase 2: 数据层基础 (已完成)
- [x] **核心模型 (`WingModels.swift`)**:
    - `RawFragment` (含外部图片存储).
    - `DailySession` (配置级联删除).
    - `WingEntry` (包含用于 JSON 结构的计算属性).
    - `AppSettings` & `Memory` 模型.
- [x] **模型容器**: 在 `WingApp.swift` 中配置.
- [x] **验证 (`ModelTests.swift`)**:
    - CRUD 操作验证.
    - 图片外部存储验证.
    - 级联删除验证.
    - 复杂数据类型 (JSON) 验证.

---

## ✅ Phase 3: 核心服务 (大脑) (已完成)
**目标**: 将 `aiService.ts` 逻辑迁移到 Swift Actors，并建立安全的偏好设置。

- [x] **3.1 安全层** (`Utils/KeychainHelper.swift`)
    - [x] 创建 `KeychainHelper` 类 (Singleton/Static).
    - [x] 实现基于 `kSecClassGenericPassword` 的增删改查.
- [x] **3.2 AI 服务引擎** (`Services/AIService.swift`)
    - [x] 定义 `AIConfig` 结构 (API Key, Model, Provider).
    - [x] 创建 `actor AIService`.
    - [x] 实现流式合成 `synthesizeJournalStream(fragments:config:) -> AsyncThrowingStream`.
    - [x] 移植 Prompt Engineering 逻辑 (自 `aiService.ts`).
    - [x] 实现 SSE (Server-Sent Events) 手动解析 (OpenAI & Gemini).
- [x] **3.3 用户设置与 UI**
    - [x] 实现 `SettingsManager` (SwiftData + Keychain).
    - [x] 创建 `SettingsEntryView` 用于 AI 配置.
    - [x] 验证持久化与安全性.

> 📖 技术回顾: [phase3-retrospective.md](.agent/memories/phase3-retrospective.md)

---

## ✅ Phase 4: UI 架构 (骨架) (已完成)
**目标**: 建立导航系统和应用结构。

- [x] **4.1 导航基础设施**
    - [x] 定义 `AppRoute` 枚举 (Chat, JournalDetail, Settings 等).
    - [x] 创建 `NavigationManager` (`@Observable` class) 用于状态管理.
- [x] **4.2 主 Tab 视图**
    - [x] Tab 1: **当下 (Today)** - 聊天/记录界面.
    - [x] Tab 2: **回忆 (Journal)** - 历史列表.
    - [x] Tab 3: **设置 (Settings)**.

> 📖 技术回顾: [phase4-retrospective.md](.agent/memories/phase4-retrospective.md)

---

## ✅ Phase 5: 输入工作流 (当下) (已完成)
**目标**: 复刻类聊天式的记录体验。

- [x] **5.1 聊天界面** (`Views/Chat/ChatView.swift`)
    - [x] 使用 `@Query` 获取今日的 `DailySession`.
    - [x] 实现 `ScrollView` + `LazyVStack` 以提升性能.
    - [x] 渲染 `FragmentBubble` 视图 (文本 & 图片).
- [x] **5.2 输入区域**
    - [x] 文本输入框 (自适应高度).
    - [x] 输入体验优化 (通过 Phase 10 持续打磨).
    - [x] **照片选择器**: 集成 `PhotosPicker` (SwiftUI Native).
    - [x] **触感反馈**: 发送时增加 `UIImpactFeedbackGenerator`.
    - [x] **日期导航**: 健壮的日期切换与日历 (`DateNavigator.swift`).

> 📖 技术回顾: [phase5-retrospective.md](.agent/memories/phase5-retrospective.md)

---

## ✅ Phase 6: 输出工作流 (日记) (已完成)
**目标**: 渲染 AI 合成的日记条目。

- [x] **6.1 Markdown 渲染**
    - [x] 实现原生 `AttributedString(markdown:)` 解析器（含段落分割）.
    - [x] 样式化标题、列表、加粗以匹配 Wing 的美学.
- [x] **6.2 日记详情** (`Views/Journal/JournalDetailView.swift`)
    - [x] 封面图区域（支持点击缩放）.
    - [x] 显示元数据: 标题、日期 (含 Fallback).
    - [x] 显示 AI 洞察 ("猫头鹰的评论").
    - [x] 渲染 Markdown 正文.
- [x] **6.3 日记合成**
    - [x] `JournalSynthesisService`: 编排合成流程.
    - [x] `AIService.synthesizeJournal`: 单次请求 JSON 模式.
    - [x] `SynthesisProgressView`: 循环鼓励语 + 时间预估 (S3 重构).
    - [x] **Fallback**: JSON 解析失败时 → 保存为 "无题日记".

> 📖 技术回顾: [phase6-retrospective.md](.agent/memories/phase6-retrospective.md)

---

## ✅ Phase 7: 设置与打磨 (已完成)
**目标**: 完成设置 UI 并进行发布前的打磨。

- [x] **7.1 设置视图**
    - [x] AI 服务商配置 (API Key 输入 -> Keychain).
    - [x] 完善模型列表与服务商配置 (OpenAI/Gemini/DeepSeek 预设列表).
    - [x] 设置 UI 重构 (模块化分区).
- [x] **7.2 数据管理**
    - [x] 导出/备份逻辑 (全量 JSON 导出).
    - [x] 单篇导出 (Markdown).
- [x] **7.3 细节打磨**
    - [x] App 图标与资源配置.
    - [x] 深色模式优化.
    - [x] 触感反馈集成.

---

## ✅ Phase 8: AI Agent 与高级特性 (已完成)
**目标**: 深化 AI 集成与个性化能力。

- [x] **8.1 高级个性化**
    - [x] `WritingStyle` 设置 UI (书信、散文、报告).
    - [x] 自定义 Prompt 编辑器 (`writingStylePrompt`, `insightPrompt`).
- [x] **8.2 AI Agent 能力**
    - [x] 长期记忆 (语义/情景/程序性记忆提取).
    - [x] 上下文感知的 RAG 检索 (用于日记合成).
- [x] **8.3 高级数据特性**
    - [x] 导入逻辑 (从 JSON 备份恢复).
    - [x] 记忆整合与管理 UI.
    - [ ] iCloud 同步 (CloudKit 集成) - *暂缓 (Phase 13)*

---

## ✅ Phase 9: UI 优化与高级设置 (已完成)
**目标**: 实现完整的设置、可视化功能及多语言支持。

- [x] **9.1 本地化 (I18N)**
    - [x] **多语言**: 中文 (简体)、英文、日文.
    - [x] **动态切换**: 无需重启 App 即时刷新语言.
    - [x] **深度集成**: AI Prompts, 错误信息, 导出内容均已本地化.
    - [x] **线程安全**: 修复了 `L()` 在后台线程的并发问题 (自动回退).
    - [x] **设置页修复**: 修复了日语环境下的显示问题 (`settings.ai.titleStyle`).
- [x] **9.2 数据可视化**
    - [x] 日历热力图 (`CalendarHeatmapView`) - 按日追踪活跃度.
    - [x] 统计仪表盘 (挥动次数, 羽毛总数).
- [x] **9.3 高级显示设置**
    - [ ] 字体选择 (已排除).
    - [x] 字号缩放 (大/中/小).
    - [x] 主题切换 (跟随系统 / 浅色 / 深色).
- [x] **9.4 高级数据管理**
    - [x] 通用文件导入/替换 (.json/.zip) - 严格区分流程.
    - [x] 文件夹导入 (iOS Files 集成).
    - [x] "清空所有数据" (带严格确认).
- [x] **9.5 记忆集成**
    - [x] RAG 集成: 合成时的检索逻辑.
    - [x] 记忆手动管理 (删除/合并 UI).

> 📖 技术回顾: [phase9-retrospective.md](.agent/memories/phase9-retrospective.md)

---

## ✅ Phase S3: 交互革新 (已完成 - 2026-02-16)
**目标**: 实现全新的 "Liquid Glass" 交互语言与 "气泡汇聚" 合成动画。

- [x] **S3.1 导航栏重构**
    - [x] **Liquid Glass TabBar**: 胶囊形状 + 超薄材质 + 毛玻璃效果.
    - [x] **布局调整**: 左侧 (日记/设置) 与 右侧 (当下/记录) 分组布局.
- [x] **S3.2 "气泡收集" 合成动画**
    - [x] **蓄力阶段**: 长按 "+" 键触发圆环填充，视图中所有可见气泡同步高亮 (`Charging Glow`).
    - [x] **汇聚阶段**: 粒子从各气泡位置发散，按抛物线路径汇聚至左下角日记 Tab.
    - [x] **状态反馈**: 合成期间日记 Tab 持续脉冲并变为主题色，完成后图标变为 Checkmark.
- [x] **S3.3 交互细节修复**
    - [x] **并发安全**: 解决了 Swift 6 模式下的 Timer 闭包非 Sendable 捕获警告.
    - [x] **操作冲突**: 修复了长按启动合成后，松手误触发记录表单弹出的问题.
    - [x] **Anchor 稳定性**: 实现了基于 GeometryProxy 的鲁棒性锚点解析 fallback 机制.

---

## 🏗️ Phase 10: 深度体验打磨 (Deep Polish)
**目标**: 专注 App 内部的交互细节与稳定性，确保核心循环流畅无阻。

- [x] **10.1 核心功能完善 (已修复)**
    - [x] **图片浏览器回归修复**: 修复了查看详情图片时的黑屏/白屏问题.
    - [x] **日记操作增强**: 修复删除后列表不刷新问题；校正日期显示逻辑.
    - [x] **本地化补全**: 修复了删除确认弹窗及日语文本未翻译问题.
- [x] **10.2 输入与编辑体验**
    - [x] **长文本优化**: 优化输入框的高度自适应、光标定位及键盘遮挡处理.
    - [x] **日记操作增强**: 增加复制全文、导出单篇 Markdown、重新编辑功能.
- [x] **10.3 AI 生成多样性**
    - [x] **跨日期合成**: 允许在日期导航器选定任意日期进行日记合成 (Time Travel Synthesis).
    - [x] **文风随机性**: 优化 Title 与 Emoji 的选择逻辑，避免千篇一律的格式.
- [x] **10.4 空状态与视觉一致性**
    - [x] **统一空状态组件**: 创建 `EmptyStateView` 并替换系统默认的 `ContentUnavailableView`.
    - [x] **全场景覆盖**: 适配日记列表、记忆列表、合并预览及详情页.
    - [x] **聊天页定制**: 为 ChatView 实现极简风格(无标题)的空状态引导.
- [x] **10.5 视觉深度重构 (Visual Refactor)**
    - [x] **Liquid Glass 2.0**: 全面升级 iOS 26 原生 `glassEffect` API (取代 `ultraThinMaterial`).
    - [x] **动态通透**: TabBar 采用 `GlassEffectContainer` + 滚动穿透优化 (`contentMargins`).
    - [x] **组件标准化**: 统一按钮与 Sheet 的玻璃质感。
    - [x] **ChatView 重构**: `DateNavigator` 悬浮胶囊设计 (无背景) + 智能日期显示 ("前天").
    - [x] **视觉一致性**: 统一 `ComposerView` 底栏与 Sheet 背景材质.
    - [ ] **10.6 上线前最后检查 (Pre-launch Checklist)**
        - [ ] **文案润色**: 对全局提示文案进行润色和本地化检查 (CN/EN/JA).
        - [ ] **数据完整性**: 再次确认全量导出 (JSON) 和导入恢复流程是否正常.
        - [ ] **代码清理**: 去除无用的测试数据、调试代码及相关注入逻辑.

---

## 🚀 Phase 11: 新用户旅程 (Onboarding)
**目标**: 打造令人印象深刻的首 5 分钟体验 (First Run Experience)。

- [ ] **11.1 启动引导**
    - [ ] **Welcome Entry**:首次启动自动生成一篇介绍 Wing 功能的日记 (预置数据).
    - [ ] **Onboarding Slides**: 简洁的功能引导页 (SwiftUI 动画演示).
- [ ] **11.2 第零配置**
    - [ ] **启动屏动画**: 实现 Logo 呼吸或展开的 Launch Screen 动画.
    - [ ] **默认设置优化**: 内置各服务商 (OpenAI/Gemini) 推荐模型列表，减少用户配置负担.
    - [x] **空白状态 (Empty State)**: 优化新一天的默认提醒样式与提示语. (已在 Phase 10.4 完成)

---

## 🏁 Phase 12: 发布冲刺 (Launch Ready)
**目标**: 完成 App Store 上架的所有外部准备工作。

- [ ] **12.1 商店资产**
    - [ ] **App Icon**: 导出全尺寸生产级图标资源 (AppIcon set).
    - [ ] **Screenshots**: 制作 EN/ZH/JA 多语言版本的 App Store 截图.
    - [ ] **Privacy Policy**: 托管隐私政策页面.
- [ ] **12.2 TestFlight 分发**
    - [ ] **Archive**: 构建发布版本.
    - [ ] **Upload**: 上传至 App Store Connect.
    - [ ] **Internal Testing**: 这里进行最后真机验证 (性能 & 内存).

---

## 🔮 Phase 13: 未来展望 (Future - TBD)
**目标**: 版本稳定后的功能迭代方向。

- [ ] **iCloud Sync**: 基于 CloudKit 的多设备同步.
- [ ] **iPad/Mac**: 大屏适配与多窗口支持.
- [ ] **Widget**: 桌面小组件 (热力图/今日回顾).

---

## 📝 开发者指南

### 工作流
1. **阅读上下文**: 检查此路线图确认当前阶段.
2. **参考 Web 代码**: 查看 `Wing-main` 文件逻辑, 使用 Swift 模式重写.
3. **使用工作流**: 运行 `/add-service` 添加新服务.
4. **验证**: 重大变更后运行测试.

### 技术回顾 (Retrospectives)
每个阶段的回顾文档均位于 `.agent/memories/`:
- `phase3-retrospective.md` - AI Service, Keychain, SSE
- `phase4-retrospective.md` - Navigation, Tab Architecture
- `phase5-retrospective.md` - DateNavigator, Image Compression
- `phase6-retrospective.md` - Swift 6 Concurrency, SwiftData Isolation
- `phase7-retrospective.md` - Settings Modularization, Dark Mode
- `phase8-retrospective.md` - Memory RAG, Prompt Engineering
- `phase9-retrospective.md` - Localization, Thread Safety, Advanced Settings