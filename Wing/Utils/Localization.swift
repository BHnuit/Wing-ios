//
//  Localization.swift
//  Wing
//
//  Created on 2026-02-13.
//

import Foundation

/**
 * 本地化辅助工具
 *
 * 提供基于 SettingsManager 中语言设置的动态本地化支持。
 * 使用 `.lproj` 目录中的 `Localizable.strings` 文件作为翻译数据源。
 */

// MARK: - Bundle Extension

extension Bundle {
    /// 根据当前用户语言设置获取对应的本地化 Bundle
    /// 包含线程安全检查：后台线程回退到系统 Bundle 以避免 SwiftData 并发崩溃
    /// 使用 nonisolated 防止编译器将整个属性推断为 MainActor
    nonisolated static var localizedBundle: Bundle {
        // 1. 线程安全检查
        if Thread.isMainThread {
            // 2. 主线程：安全访问 MainActor 隔离的 SettingsManager
            // 使用 assumeIsolated 消除编译器警告，因为我们已经检查了 Thread.isMainThread
            return MainActor.assumeIsolated {
                let language = SettingsManager.shared.appSettings?.language ?? .zh
                let lprojName: String
                
                switch language {
                case .zh: lprojName = "zh-Hans"
                case .en: lprojName = "en"
                case .ja: lprojName = "ja"
                }
                
                // 加载对应的 .lproj Bundle
                if let path = Bundle.main.path(forResource: lprojName, ofType: "lproj"),
                   let bundle = Bundle(path: path) {
                    return bundle
                }
                
                // Fallback: 尝试 zh-Hans
                if let path = Bundle.main.path(forResource: "zh-Hans", ofType: "lproj"),
                   let bundle = Bundle(path: path) {
                    return bundle
                }
                
                return Bundle.main
            }
        } else {
            // 3. 后台线程：回退到系统默认 Bundle (Bundle.main)
            // 这可以防止在 Log 或后台任务中访问 UI 绑定的 SwiftData 模型导致崩溃
            return Bundle.main
        }
    }
}

// MARK: - Localization Function

/**
 * 全局本地化快捷函数
 *
 * 从当前语言设置对应的 Localizable.strings 中获取翻译字符串。
 * 显式声明 nonisolated 以允许从任何上下文同步调用
 *
 * - Parameter key: 翻译键
 * - Returns: 翻译后的字符串，如果键不存在则返回键本身
 */
nonisolated func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: Bundle.localizedBundle, comment: "")
}
