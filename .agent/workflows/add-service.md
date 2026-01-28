---
description: 创建一个新的核心 Service (Actor) 并集成 Keychain 与测试
---

此 Workflow 总结了 Phase 3 中建立的最佳实践，用于指导如何创建符合项目架构的新 Service。

## 1. 定义 Service (Actor)

在 `Wing/Services` 目录下创建新文件 `[ServiceName].swift`。
**规则**：
*   必须使用 `actor` 关键字以确保并发安全（Swift 6 Strict Concurrency）。
*   通常使用单例模式 `static let shared`，除非有特殊状态管理需求。
*   引入 `Foundation` 和其他必要框架。

```swift
// [ServiceName].swift
import Foundation

actor [ServiceName] {
    static let shared = [ServiceName]()
    
    private init() {}
    
    // 示例方法
    func performAction() async throws -> String {
        return "Result"
    }
}
```

## 2. 集成 Keychain (如涉及敏感信息)

如果 Service 需要管理 API Key、Token 或密码，**严禁**使用 UserDefaults 或 SwiftData 存储明文。
**规则**：
*   使用 `KeychainHelper.shared` 进行存取。
*   Key 的命名空间建议主要以 Service 或用来区分 Provider 的枚举值为前缀。

```swift
private let keychain = KeychainHelper.shared

func saveGenericPassword(_ secret: String) async {
    // 异步写入 Keychain
    try? await keychain.save(secret, for: "service_secret_key")
}

func getGenericPassword() async -> String? {
    // 异步读取
    return try? await keychain.loadString(for: "service_secret_key")
}
```

## 3. 实现业务逻辑

编写具体的业务方法。
**注意**：
*   所有 Actor 的外部调用均为 `async`。
*   如果需要对外暴露非异步属性（如 UI 绑定），考虑配套创建一个 `@Observable` 的 Manager 类（如 `SettingsManager`），或者使用 `MainActor` 隔离的 ViewModel 来中转。

## 4. 编写并发测试 (Swift Testing)

在 `WingTests` 目录下创建对应的测试文件 `[ServiceName]Tests.swift`。
**规则**：
*   使用现代 `Testing` 框架 (Swift Testing)。
*   使用 `@Suite` 和 `@Test` 宏。
*   利用 `await` 测试 Actor 的并发行为。

```swift
// [ServiceName]Tests.swift
import Testing
@testable import Wing

@Suite("[ServiceName] Tests")
struct [ServiceName]Tests {
    
    @Test("Basic Functionality")
    func testBasicFunctionality() async throws {
        let service = [ServiceName].shared
        let result = try await service.performAction()
        #expect(result == "Result")
    }
    
    @Test("Keychain Integration")
    func testKeychain() async throws {
        // 编写集成测试时，注意清理测试数据
        // ...
    }
}
```
