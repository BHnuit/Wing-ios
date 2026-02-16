---
description: 优化 UI 界面的规范，包含颜色资产、触感反馈、预览宏与视觉核对的标准流程
---

此 Workflow 定义了 Wing 项目中 UI 开发与优化的标准规范，确保界面的一致性、可交互性与视觉质量。

## 1. 颜色规范：使用 BrandColors 资产

### 1.1 强制规则
**严禁**在代码中直接使用系统颜色字面量（如 `.blue`, `.red`, `.green`）。所有颜色必须引用 `Assets.xcassets` 中定义的 **BrandColors** 色板。

```swift
// ❌ 禁止：直接使用系统颜色
Text("Hello")
    .foregroundStyle(.blue)

Button("Save") { }
    .tint(.green)

// ✅ 推荐：使用 BrandColors 资产
Text("Hello")
    .foregroundStyle(Color("BrandPrimary"))

Button("Save") { }
    .tint(Color("BrandAccent"))
```

### 1.2 推荐做法：定义颜色扩展
为避免魔法字符串，建议在项目中维护一个 `Color+Brand.swift` 扩展：

```swift
extension Color {
    static let brandPrimary = Color("BrandPrimary")
    static let brandSecondary = Color("BrandSecondary")
    static let brandAccent = Color("BrandAccent")
    static let brandBackground = Color("BrandBackground")
    static let brandSurface = Color("BrandSurface")
    static let brandTextPrimary = Color("BrandTextPrimary")
    static let brandTextSecondary = Color("BrandTextSecondary")
    // 根据项目需要扩展...
}

// 使用示例
Text("Hello")
    .foregroundStyle(.brandPrimary)
```

### 1.3 新增颜色流程
1. 在 `Assets.xcassets` 中的 `BrandColors` 文件夹下新增 Color Set。
2. 确保同时定义 **Light** 和 **Dark** 外观变体。
3. 在 `Color+Brand.swift` 中添加对应的静态属性。

---

## 2. 触感反馈：所有按钮必须支持 Haptic Feedback

### 2.1 强制规则
所有用户可交互的按钮（`Button`, 自定义 tap gesture 等）在触发操作时，必须附带 **触感反馈 (Haptic Feedback)**。

### 2.2 推荐实现

#### 方式一：使用 `.sensoryFeedback` 修饰符 (iOS 17+，推荐)

```swift
// ✅ 推荐：使用 SwiftUI 原生修饰符
Button("提交") {
    performSubmit()
}
.sensoryFeedback(.impact(weight: .medium), trigger: submitTrigger)
```

#### 方式二：封装 Haptic 工具函数

```swift
enum HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// 使用示例
Button("保存") {
    HapticManager.impact(.medium)
    performSave()
}
```

### 2.3 触感类型选择指南

| 交互场景 | 推荐触感类型 | 说明 |
|----------|-------------|------|
| 普通按钮点击 | `.impact(.medium)` | 标准交互反馈 |
| 轻量级切换 (Toggle/Tab) | `.impact(.light)` 或 `.selection()` | 轻柔不突兀 |
| 重要/破坏性操作 | `.impact(.heavy)` | 强调操作的重要性 |
| 操作成功 | `.notification(.success)` | 正向反馈 |
| 操作失败/错误 | `.notification(.error)` | 警示反馈 |
| 列表滑动/选择变化 | `.selection()` | 精细的选择反馈 |

---

## 3. 预览规范：使用 `#Preview` 宏

### 3.1 强制规则
所有新建或修改的 SwiftUI View 必须使用 **`#Preview` 宏**，**严禁**使用旧版 `PreviewProvider` 协议。

```swift
// ❌ 禁止：旧版 PreviewProvider
struct MyView_Previews: PreviewProvider {
    static var previews: some View {
        MyView()
    }
}

// ✅ 推荐：#Preview 宏
#Preview {
    MyView()
}

// ✅ 带标题的预览（适用于多个预览变体）
#Preview("Dark Mode") {
    MyView()
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    MyView()
        .preferredColorScheme(.light)
}
```

### 3.2 预览数据注入
若 View 依赖 `ModelContext` 或环境变量，需在 Preview 中正确注入：

```swift
#Preview {
    MyView()
        .modelContainer(for: WingEntry.self, inMemory: true)
        .environment(NavigationManager())
}
```

---

## 4. 视觉核对：执行 RenderPreview 工具

### 4.1 强制规则
**任何 UI 变动**（包括但不限于颜色修改、布局调整、新增组件）完成后，必须执行 **RenderPreview 工具** 进行视觉核对，确保：
- 界面在 Light / Dark 模式下均正常显示。
- 颜色、间距、字体与设计规范一致。
- 无布局截断、溢出或错位问题。

### 4.2 核对流程
1. 完成代码修改。
2. 确保 `#Preview` 宏已正确编写且包含必要的依赖注入。
3. 执行 RenderPreview 工具渲染预览截图。
4. 核对截图是否符合预期，如有问题立即修复后重新渲染。

---

## 5. 组件复用：ShipSwift Recipe库

### 5.1 优先检索原则
在从零构建复杂 UI 组件或动画前，**必须优先检索 ShipSwift Recipe 库**。ShipSwift 提供了大量经过生产环境验证的高质量 iOS 组件和效果。

- **检索命令**: 使用 Agent 工具 `shipswift searchRecipes` 或 `shipswift listRecipes`。
- **获取代码**: 使用 `shipswift getRecipe` 获取完整实现。

### 5.2 适配规范
获取 Recipe 代码后，**严禁直接粘贴使用**，必须根据 Wing 项目规范进行适配：

1.  **颜色替换**: 将 Recipe 中的硬编码颜色或自定义色板替换为 `Assets.xcassets` 中的 **BrandColors**。
2.  **数据模型**: 将 Recipe 的数据结构替换为项目中的 `SwiftData` 模型或 ViewModel。
3.  **代码风格**: 调整缩进、命名和修饰符顺序以符合项目代码风格。

### 5.3 推荐场景
- **复杂动画**: 如 Mesh Gradient, Shimmer Effect, 粒子效果等。
- **通用组件**: 如 Onboarding View, Settings View, Custom Tab Bar 等。
- **图表展示**: 各类 Swift Charts 图表。

---

## 6. Checklist

- [ ] **Simply First**: 复杂组件已先在 ShipSwift 中检索是否有现成方案。
- [ ] **ShipSwift 适配**: 若使用了 Recipe，已完全适配 BrandColors 和项目数据模型。
- [ ] **颜色**: 所有颜色均引用 BrandColors 资产，无系统颜色字面量（`.blue`, `.red` 等）。
- [ ] **颜色扩展**: 新增颜色已在 `Color+Brand.swift` 中注册静态属性。
- [ ] **Dark Mode**: 新增的 Color Set 同时定义了 Light 和 Dark 变体。
- [ ] **触感反馈**: 所有按钮和交互元素均附带 Haptic Feedback。
- [ ] **触感类型**: 根据交互场景选择了合适的触感类型（参考 §2.3 指南）。
- [ ] **预览宏**: 使用 `#Preview` 宏，未使用 `PreviewProvider`。
- [ ] **预览数据**: Preview 中正确注入了 `ModelContainer` 及环境依赖。
- [ ] **视觉核对**: 已执行 RenderPreview 工具核对 UI 效果，Light/Dark 模式均无异常。
