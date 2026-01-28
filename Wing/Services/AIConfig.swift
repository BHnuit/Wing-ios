//
//  AIConfig.swift
//  Wing
//
//  Created on 2026-01-29.
//

import Foundation

/**
 * AI 服务配置
 * 用于将 AppSettings 解耦，方便单独测试与传递
 */
struct AIConfig {
    /// AI 供应商
    let provider: AiProvider
    
    /// 模型名称 (e.g. "gemini-1.5-flash", "gpt-4o")
    let model: String
    
    /// API Key
    let apiKey: String
    
    /// 自定义 Base URL (仅当 provider == .custom 或 .openai / .deepseek 需要覆盖时使用)
    let baseURL: String?
    
    /// 系统提示词 (System Instruction)
    let systemPrompt: String?
    
    /// 初始化
    init(
        provider: AiProvider,
        model: String,
        apiKey: String,
        baseURL: String? = nil,
        systemPrompt: String? = nil
    ) {
        self.provider = provider
        self.model = model
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.systemPrompt = systemPrompt
    }
}
