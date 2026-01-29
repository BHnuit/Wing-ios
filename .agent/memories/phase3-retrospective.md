# Phase 3 技术挑战与解决方案总结

> **阶段**: Core Services (The Brain)
> **目标**: AI 服务、Keychain 安全、用户设置

---

## 🔥 最大挑战：Swift 6 Actor 与 SSE 流式解析

### 问题本质
将 TypeScript 的 `aiService.ts` 逻辑迁移到 Swift Actor，同时处理 Server-Sent Events (SSE) 流式响应。

### 具体表现
1. **SSE 手动解析**：iOS 没有原生 SSE 库，需要手动解析 `data:` 前缀的行
2. **OpenAI vs Gemini 格式差异**：两个供应商的 JSON 结构完全不同
3. **AsyncThrowingStream 的正确使用**：流的生命周期管理

### 解决方案

```swift
// SSE 解析核心逻辑
for try await line in response.bytes.lines {
    guard line.hasPrefix("data: ") else { continue }
    let jsonString = String(line.dropFirst(6))
    if jsonString == "[DONE]" { break }
    // 解析 JSON...
}

// 多供应商适配
switch config.provider {
case .openAI: return try parseOpenAIChunk(data)
case .gemini: return try parseGeminiChunk(data)
}
```

---

## 🔐 Keychain 安全层

### 问题
API Key 必须安全存储，不能用 UserDefaults。

### 解决方案
封装 `KeychainHelper` 单例，使用 `kSecClassGenericPassword`：

```swift
class KeychainHelper {
    static let shared = KeychainHelper()
    
    func save(_ value: String, for key: String) throws {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
}
```

---

## 📊 SettingsManager 双层存储

### 问题
设置需要持久化到 SwiftData，但敏感信息（API Key）必须存 Keychain。

### 解决方案
`SettingsManager` 作为协调层：

- **SwiftData**: 存储 `AppSettings`（provider、model、baseURL）
- **Keychain**: 存储 API Key
- **getAIConfig()**: 组合两者返回完整配置

---

## 💡 核心体感

1. **SSE 不是 WebSocket**，需要手动解析每行
2. **多供应商适配**：用 switch 分发，不要 if-else 嵌套
3. **敏感信息分离**：Keychain 和 SwiftData 各司其职
