//
//  JournalLanguage.swift
//  Wing
//
//  Created on 2026-01-30.
//

import Foundation

/**
 * 日记生成语言 (传入 AIService System Prompt)
 */
enum JournalLanguage: String, Codable, CaseIterable, Sendable {
    case auto = "auto"   // 自动检测 fragment 语言
    case zh = "zh"       // 强制中文
    case en = "en"       // 强制英文
    
    var displayName: String {
        switch self {
        case .auto: return L("journal.language.auto")
        case .zh: return L("journal.language.zh")
        case .en: return L("journal.language.en")
        }
    }
    

}
