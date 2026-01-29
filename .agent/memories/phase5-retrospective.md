# Phase 5 技术挑战与解决方案总结

> **阶段**: Input Flow (The "Now")
> **目标**: 聊天界面、日期导航、图片处理

---

## 🔥 最大挑战：DateNavigator 状态同步与数据去重

### 问题本质
日期导航器需要在多个数据源（Session 日期、日历选择、左右箭头）之间保持同步，且数据可能包含重复项。

### 具体表现
1. **重复日期导致的 Bug**：`availableDates` 数组有重复，导致导航混乱
2. **右箭头失效**：`nextDate` 计算逻辑错误，找不到下一个日期
3. **日历不更新月份**：`displayedMonth` 与 `selectedDate` 不同步

### 解决方案

```swift
// 数据去重 + 排序
private var sortedUniqueDates: [String] {
    Array(Set(availableDates)).sorted()
}

// 下一个日期计算
private var nextDate: String? {
    guard let currentIndex = sortedUniqueDates.firstIndex(of: selectedDate) else {
        return nil
    }
    let nextIndex = currentIndex + 1
    guard nextIndex < sortedUniqueDates.count else {
        return nil  // 已经是最后一个
    }
    return sortedUniqueDates[nextIndex]
}

// 日历月份同步
.onChange(of: selectedDate) { _, newValue in
    if let date = parseDate(newValue) {
        displayedMonth = date
    }
}
```

---

## 📷 图片处理与压缩

### 问题
用户选择的图片可能很大（10MB+），直接存储会导致数据库膨胀。

### 解决方案

1. **ImageCompressor Actor**：压缩到目标大小（500KB）
2. **@Attribute(.externalStorage)**：大数据存外部文件
3. **PhotosPicker 原生集成**：使用 SwiftUI 原生选择器

```swift
actor ImageCompressor {
    @MainActor
    func compress(_ data: Data, maxBytes: Int = 500_000) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        
        var quality: CGFloat = 0.8
        var result = image.jpegData(compressionQuality: quality)
        
        while let data = result, data.count > maxBytes, quality > 0.1 {
            quality -= 0.1
            result = image.jpegData(compressionQuality: quality)
        }
        
        return result
    }
}
```

---

## 📜 ScrollView 自动滚动

### 问题
新消息时需要自动滚动到底部。

### 解决方案

```swift
ScrollViewReader { proxy in
    ScrollView {
        LazyVStack {
            ForEach(fragments) { fragment in
                FragmentBubble(fragment: fragment)
            }
            
            // 底部锚点
            Color.clear
                .frame(height: 1)
                .id("bottom")
        }
    }
    .onChange(of: fragments.count) { _, _ in
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}
```

---

## 💡 核心体感

1. **数据层防御性清洗**：去重 + 排序，不信任上游数据
2. **数组索引计算要小心**：边界条件（第一个、最后一个）
3. **大图片必须压缩**：500KB 是合理阈值
4. **日历组件状态多**：selectedDate、displayedMonth 要同步
5. **ScrollViewReader + id + onChange** 实现自动滚动
