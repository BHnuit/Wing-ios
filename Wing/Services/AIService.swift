//
//  AIService.swift
//  Wing
//
//  Created on 2026-01-29.
//

import Foundation

/**
 * AI 服务错误枚举
 */
enum AIError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case networkError(Error)
    case apiError(statusCode: Int, message: String)
    case parsingError
    case emptyResponse
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "缺少 API Key，请在设置中配置。"
        case .invalidURL:
            return "无效的 URL 地址。"
        case .networkError(let error):
            return "网络请求失败: \(error.localizedDescription)"
        case .apiError(let statusCode, let message):
            return "API 错误 (HTTP \(statusCode)): \(message)"
        case .parsingError:
            return "解析响应数据失败。"
        case .emptyResponse:
            return "服务器返回空数据。"
        }
    }
}

/**
 * 核心 AI 服务 Actor
 * 负责与 LLM (Gemini, OpenAI) 进行交互，特别是流式生成日记。
 */
actor AIService {
    
    static let shared = AIService()
    
    private init() {}
    
    // MARK: - Constants
    
    private let openAIBaseURL = "https://api.openai.com/v1"
    // Gemini 直接调用 REST API (通过 API Key)
    // pattern: https://generativelanguage.googleapis.com/v1beta/models/{model}:streamGenerateContent?key={apiKey}
    private let geminiBaseURL = "https://generativelanguage.googleapis.com/v1beta"
    
    // MARK: - Public API
    
    /**
     * 流式合成日记
     *
     * - Parameters:
     *   - fragments: 当日的碎片记录
     *   - config: AI 配置对象
     * - Returns: 异步抛出流，yield 每一段增量文本（Markdown 正文片段）
     */
    func synthesizeJournalStream(fragments: [RawFragment], config: AIConfig) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.processStream(fragments: fragments, config: config, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Internal Logic
    
    private func processStream(
        fragments: [RawFragment],
        config: AIConfig,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        // 1. 准备请求
        guard !config.apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }
        
        let systemInstruction = getSystemInstruction()
        let userPrompt = buildUserPrompt(from: fragments)
        
        var request: URLRequest
        
        if config.provider == .gemini {
            request = try buildGeminiRequest(config: config, system: systemInstruction, user: userPrompt)
            try await processGeminiStream(request: request, continuation: continuation)
        } else {
            request = try buildOpenAICompatibleRequest(config: config, system: systemInstruction, user: userPrompt)
            try await processOpenAIStream(request: request, continuation: continuation)
        }
    }
    
    // MARK: - Stream Handlers
    
    private func processGeminiStream(
        request: URLRequest,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError(URLError(.badServerResponse))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            var errorMsg = ""
            for try await line in bytes.lines { errorMsg += line }
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: errorMsg)
        }
        
        // Gemini REST API 返回的是 JSON 数组流。
        // 我们需要手动通过并列的大括号 `{}` 来分割 JSON 对象。
        // 逻辑：忽略最外层的 `[` 和 `]`，提取每一个顶层的 `{ ... }` 对象。
        
        var buffer = Data()
        var openBraces = 0
        var inString = false
        var isEscaped = false
        
        for try await byte in bytes {
            let char = Character(UnicodeScalar(byte))
            
            // 如果不在对象内，且遇到 '{'，开始记录
            if openBraces == 0 {
                if char == "{" {
                    openBraces = 1
                    buffer.append(byte)
                }
                // 忽略非 '{' 字符（如 '[', ',', '\n', ']'）
                continue
            }
            
            // 在对象内
            buffer.append(byte)
            
            if !inString {
                if char == "{" {
                    openBraces += 1
                } else if char == "}" {
                    openBraces -= 1
                    if openBraces == 0 {
                        // 这是一个完整的 JSON 对象
                        if let jsonObject = try? JSONSerialization.jsonObject(with: buffer) as? [String: Any],
                           let content = parseGeminiResponse(jsonObject) {
                            continuation.yield(content)
                        }
                        buffer.removeAll()
                    }
                } else if char == "\"" {
                    inString = true
                }
            } else {
                if isEscaped {
                    isEscaped = false
                } else {
                    if char == "\\" {
                        isEscaped = true
                    } else if char == "\"" {
                        inString = false
                    }
                }
            }
        }
        
        continuation.finish()
    }
    
    private func processOpenAIStream(
        request: URLRequest,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError(URLError(.badServerResponse))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            var errorMsg = ""
            for try await line in bytes.lines { errorMsg += line }
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: errorMsg)
        }
        
        for try await line in bytes.lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard trimmedLine.hasPrefix("data: ") else { continue }
            
            let dataStr = trimmedLine.dropFirst(6).trimmingCharacters(in: .whitespaces)
            if dataStr == "[DONE]" { break }
            
            if let content = parseOpenAIResponse(jsonString: dataStr) {
                continuation.yield(content)
            }
        }
        
        continuation.finish()
    }
    
    // MARK: - Prompt Engineering
    
    private func getSystemInstruction() -> String {
        return """
        Role: You are "Wing", an empathetic AI diary assistant.
        Task: Write a cohesive diary entry based on the user's raw fragments for the day.
        Format: Output ONLY the diary content in Markdown. Do not wrap in JSON. Do not include title or other metadata fields.
        Language: Detect language (Chinese/English) from fragments or default to Chinese.
        Tone: Warm, reflective, literary.
        """
    }
    
    private func buildUserPrompt(from fragments: [RawFragment]) -> String {
        let fragmentTexts = fragments.map { fragment in
            let timeStr = Date(timeIntervalSince1970: TimeInterval(fragment.timestamp) / 1000).formatted(date: .omitted, time: .shortened)
            let imageMarker = fragment.type == .image ? "[Image]" : ""
            return "[\(timeStr)] \(imageMarker) \(fragment.content)"
        }.joined(separator: "\n")
        
        return """
        User's fragments for today:
        
        \(fragmentTexts)
        
        Write the diary content now.
        """
    }
    
    // MARK: - Request Builders
    
    private func buildOpenAICompatibleRequest(config: AIConfig, system: String, user: String) throws -> URLRequest {
        let baseURL = config.baseURL ?? openAIBaseURL
        let urlString = baseURL.trimmingCharacters(in: .init(charactersIn: "/")) + "/chat/completions"
        guard let url = URL(string: urlString) else { throw AIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "stream": true,
            "max_tokens": 4096
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
    
    private func buildGeminiRequest(config: AIConfig, system: String, user: String) throws -> URLRequest {
        // Gemini URL: https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:streamGenerateContent?key=YOUR_API_KEY
        let model = config.model.isEmpty ? "gemini-2.5-flash" : config.model
        let urlString = "\(geminiBaseURL)/models/\(model):streamGenerateContent?key=\(config.apiKey)"
        
        guard let url = URL(string: urlString) else { throw AIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Gemini JSON Format
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": user]
                    ]
                ]
            ],
            "system_instruction": [
                "parts": [
                    ["text": system]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
    
    // MARK: - Parsers
    
    private func parseOpenAIResponse(jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let delta = firstChoice["delta"] as? [String: Any],
              let content = delta["content"] as? String else {
            return nil
        }
        return content
    }
    
    private func parseGeminiResponse(_ json: [String: Any]) -> String? {
        guard let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let contentObj = firstCandidate["content"] as? [String: Any],
              let parts = contentObj["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            return nil
        }
        return text
    }
}
