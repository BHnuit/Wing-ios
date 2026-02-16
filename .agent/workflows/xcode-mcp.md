---
description: Xcode MCP 工具使用指南，包含项目构建、测试、预览与代码导航的最佳实践
---

此 Workflow 旨在指导如何高效利用 Xcode MCP 工具进行 iOS 开发。通过 Xcode MCP，我们可以直接与 Xcode 项目交互，获取编译状态、运行测试、渲染预览以及执行更精准的代码搜索。

## 1. 项目构建与诊断 (Build & Diagnostics)

### 1.1 构建项目
在每次重构或大量代码修改后，务必构建项目以确保无编译错误。

- **工具**: `mcp_xcode_BuildProject`
- **场景**: 修改了 Model、Service 或核心逻辑后。
- **参数**: `tabIdentifier` (通常由 Agent 自动获取或留空尝试默认)

### 1.2 获取构建日志
构建失败时，使用此工具分析具体的错误原因。

- **工具**: `mcp_xcode_GetBuildLog`
- **参数**: `severity` (建议 'error'), `tabIdentifier`
- **技巧**: 配合 `mcp_xcode_XcodeRefreshCodeIssuesInFile` 可以获取特定文件的详细诊断信息。

---

## 2. 测试运行 (Testing)

### 2.1 运行所有测试
在完成通过重构或新功能开发后，进行回归测试。

- **工具**: `mcp_xcode_RunAllTests`
- **场景**: 提交代码前，确保未破坏现有功能。

### 2.2 运行特定测试
针对性地测试某个功能模块或 Debug 修复。

- **工具**: `mcp_xcode_RunSomeTests`
- **流程**:
    1. 使用 `mcp_xcode_GetTestList` 获取所有可用测试。
    2. 提取目标测试的 `targetName` 和 `testIdentifier`。
    3. 调用 `mcp_xcode_RunSomeTests`。

---

## 3. UI 预览与验证 (UI Verification)

### 3.1 渲染 SwiftUI 预览
无需启动模拟器，直接获取 View 的渲染效果截图。

- **工具**: `mcp_xcode_RenderPreview`
- **场景**: 调整 UI 布局、颜色或排版后。
- **参数**: `sourceFilePath` (View 文件路径), `previewDefinitionIndexInFile` (通常为 0)
- **注意**: 确保文件中包含有效的 `#Preview` 宏。

---

## 4. 代码导航与搜索 (Code Navigation)

### 4.1 项目结构浏览
基于 Xcode 项目结构（Group/Reference）而非文件系统目录浏览项目。这对于理解大型项目结构更有帮助。

- **工具**: `mcp_xcode_XcodeLS` / `mcp_xcode_XcodeGlob`
- **优点**: 能过滤掉非项目文件，只关注 `.xcodeproj` 中引用的资源。

### 4.2 语义级搜索
在 Xcode 项目范围内搜索代码定义或引用。

- **工具**: `mcp_xcode_XcodeGrep`
- **场景**: 查找某个类或方法在项目中的所有使用位置。

---

## 5. 文档查询 (Documentation)

### 5.1 查询 Apple 官方文档
直接获取 API 的官方说明和示例。

- **工具**: `mcp_xcode_DocumentationSearch`
- **场景**: 不确定某个 SwiftUI 修饰符的用法或参数时。

## 6. 最佳实践 Workflow

1.  **修改代码** -> **构建项目** (`BuildProject`) -> **获取错误** (`GetBuildLog`) -> **修复**。
2.  **调整 UI** -> **渲染预览** (`RenderPreview`) -> **视觉核对**。
3.  **重构逻辑** -> **运行相关测试** (`RunSomeTests`) -> **确保通过**。

通过这些工具组合，我们可以实现类似 Xcode IDE 内的开发体验。
