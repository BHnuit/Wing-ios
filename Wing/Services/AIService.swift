//
//  AIService.swift
//  Wing
//
//  Created on 2026-01-29.
//

import Foundation

// MARK: - Memory Extraction Types (Moved to WingModels.swift)

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
            return L("ai.error.missingKey")
        case .invalidURL:
            return L("ai.error.invalidURL")
        case .networkError(let error):
            return String(format: L("ai.error.network"), error.localizedDescription)
        case .apiError(let statusCode, let message):
            return String(format: L("ai.error.api"), statusCode, message)
        case .parsingError:
            return L("ai.error.parsing")
        case .emptyResponse:
            return L("ai.error.empty")
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
    private let deepSeekBaseURL = "https://api.deepseek.com/v1"
    // Gemini 直接调用 REST API (通过 API Key)
    // pattern: https://generativelanguage.googleapis.com/v1beta/models/{model}:streamGenerateContent?key={apiKey}
    private let geminiBaseURL = "https://generativelanguage.googleapis.com/v1beta"
    
    // MARK: - Public API
    
    /**
     * 验证 API Key 是否有效（最小 token 消耗）
     *
     * - Gemini: 调用 /models 接口 (免费，无 token 消耗)
     * - OpenAI/DeepSeek: 发送 "Hi" 测试请求 (约 5 tokens)
     *
     * - Parameter config: AI 配置对象
     * - Returns: 如果验证成功返回 true
     * - Throws: 如果验证失败抛出 AIError
     */
    func validateConnection(config: AIConfig) async throws -> Bool {
        guard !config.apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }
        
        if config.provider == .gemini {
            return try await validateGeminiConnection(config: config)
        } else {
            return try await validateOpenAIConnection(config: config)
        }
    }
    
    /// Gemini: 调用 /models 接口验证 (免费)
    private func validateGeminiConnection(config: AIConfig) async throws -> Bool {
        let urlString = "\(geminiBaseURL)/models?key=\(config.apiKey)"
        guard let url = URL(string: urlString) else {
            throw AIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError(URLError(.badServerResponse))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: errorMsg)
        }
        
        return true
    }
    
    /// OpenAI/DeepSeek: 发送最小 prompt 验证 (约 5 tokens)
    private func validateOpenAIConnection(config: AIConfig) async throws -> Bool {
        // 根据 provider 选择正确的端点
        let baseURL: String
        if let customURL = config.baseURL, !customURL.isEmpty {
            baseURL = customURL
        } else if config.provider == .deepseek {
            baseURL = deepSeekBaseURL
        } else {
            baseURL = openAIBaseURL
        }
        
        let urlString = baseURL.trimmingCharacters(in: .init(charactersIn: "/")) + "/chat/completions"
        guard let url = URL(string: urlString) else {
            throw AIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        let body: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "user", "content": "Hi"]
            ],
            "max_tokens": 1
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError(URLError(.badServerResponse))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: errorMsg)
        }
        
        return true
    }
    
    /**
     * 流式合成日记
     *
     * - Parameters:
     *   - fragments: 当日的碎片记录
     *   - memories: 相关记忆上下文
     *   - config: AI 配置对象
     * - Returns: 异步抛出流，yield 每一段增量文本（Markdown 正文片段）
     */
    func synthesizeJournalStream(fragments: [RawFragment], memories: [String] = [], config: AIConfig) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.processStream(fragments: fragments, memories: memories, config: config, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /**
     * 合成完整日记（JSON 模式）
     *
     * - Parameters:
     *   - fragments: 当日的碎片记录
     *   - memories: 相关记忆上下文
     *   - config: AI 配置对象
     *   - journalLanguage: 日记生成语言设置
     * - Returns: JournalOutput 结构化输出
     * - Note: 包含 Fallback 机制，解析失败时返回"无题日记"
     */
    func synthesizeJournal(
        fragments: [RawFragment],
        memories: [String] = [],
        config: AIConfig,
        journalLanguage: JournalLanguage = .auto,
        writingStyle: WritingStyle = .prose,
        writingStylePrompt: String? = nil,
        titleStyle: TitleStyle = .abstract,
        titleStylePrompt: String? = nil,
        insightPrompt: String? = nil
    ) async throws -> JournalOutput {
        guard !config.apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }
        
        let systemInstruction = getJournalSystemInstruction(
            language: journalLanguage,
            writingStyle: writingStyle,
            writingStylePrompt: writingStylePrompt,
            titleStyle: titleStyle,
            titleStylePrompt: titleStylePrompt,
            insightPrompt: insightPrompt
        )
        let userPrompt = buildUserPrompt(from: fragments, memories: memories)
        
        // 构建非流式请求
        var request: URLRequest
        if config.provider == .gemini {
            request = try buildGeminiJSONRequest(config: config, system: systemInstruction, user: userPrompt)
        } else {
            request = try buildOpenAIJSONRequest(config: config, system: systemInstruction, user: userPrompt)
        }
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError(URLError(.badServerResponse))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: errorMsg)
        }
        
        // 解析响应
        let rawContent: String
        if config.provider == .gemini {
            rawContent = try parseGeminiJSONResponse(data)
        } else {
            rawContent = try parseOpenAIJSONResponse(data)
        }
        
        // 尝试解析 JSON
        return parseJournalOutput(rawContent)
    }
    
    /**
     * 提取长期记忆（JSON 模式）
     *
     * - Parameters:
     *   - content: 日记内容
     *   - config: AI 配置对象
     *   - language: 提取语言倾向 (默认为 auto)
     * - Returns: MemoryExtractionResult 结构化输出
     */
    func extractMemories(content: String, config: AIConfig, language: JournalLanguage = .auto) async throws -> MemoryExtractionResult {
        guard !config.apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }
        
        let systemInstruction = getMemorySystemInstruction(language: language)
        
        // 构建非流式请求
        var request: URLRequest
        if config.provider == .gemini {
            request = try buildGeminiJSONRequest(config: config, system: systemInstruction, user: content)
        } else {
            request = try buildOpenAIJSONRequest(config: config, system: systemInstruction, user: content)
        }
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError(URLError(.badServerResponse))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: errorMsg)
        }
        
        // 解析响应
        let rawContent: String
        if config.provider == .gemini {
            rawContent = try parseGeminiJSONResponse(data)
        } else {
            rawContent = try parseOpenAIJSONResponse(data)
        }
        
        // 尝试解析 JSON
        return parseMemoryOutput(rawContent)
    }
    
    // MARK: - Internal Logic
    
    private func processStream(
        fragments: [RawFragment],
        memories: [String],
        config: AIConfig,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        // 1. 准备请求
        guard !config.apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }
        
        let systemInstruction = getSystemInstruction()
        let userPrompt = buildUserPrompt(from: fragments, memories: memories)
        
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
    
    private func getSystemInstruction(writingStyle: WritingStyle = .prose, writingStylePrompt: String? = nil) -> String {
        let toneInstruction = buildToneInstruction(writingStyle: writingStyle, writingStylePrompt: writingStylePrompt)
        
        return """
        Role: You are "Wing", an empathetic AI diary assistant.
        Task: Write a cohesive diary entry based on the user's raw fragments for the day.
        Format: Output ONLY the diary content in Markdown. Do not wrap in JSON. Do not include title or other metadata fields.
        Language: Detect language (Chinese/English) from fragments or default to Chinese.
        \(toneInstruction)
        """
    }
    
    private func getJournalSystemInstruction(
        language: JournalLanguage = .auto,
        writingStyle: WritingStyle = .prose,
        writingStylePrompt: String? = nil,
        titleStyle: TitleStyle = .abstract,
        titleStylePrompt: String? = nil,
        insightPrompt: String? = nil
    ) -> String {
        let instruction: String
        switch language {
        case .auto: instruction = "Detect language from fragments and write in the same language."
        case .zh: instruction = "Write the diary ONLY in Chinese (简体中文)."
        case .en: instruction = "Write the diary ONLY in English."
        }
        
        // 生成文风指令
        let toneInstruction = buildToneInstruction(writingStyle: writingStyle, writingStylePrompt: writingStylePrompt)
        
        // 生成标题指令
        let titleInstruction = buildTitleInstruction(style: titleStyle, customPrompt: titleStylePrompt)
        
        // 生成洞察提示词，如果用户没有自定义，使用默认的占位描述
        let insightValueDescription: String
        if let customInsight = insightPrompt, !customInsight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            insightValueDescription = customInsight
        } else {
            insightValueDescription = "A short reflection on the user's day. Be observant but objective."
        }
        
        return """
        Role: You are an expert ghostwriter. You have no identity of your own. Your ONLY function is to convert the user's raw fragments into a polished, first-person ("I") diary entry.

        Task: Synthesize the provided fragments into a cohesive narrative.
        Language: \(instruction)

        IMPORTANT - Writing Style (Follow strictly):
        \(toneInstruction)

        Output Format:
        Return ONLY a raw, minified JSON object. No Markdown code fences. Ensure strictly valid JSON syntax. Escape all newlines (\\n) and double quotes (\\") within string values.

        Structure:
        {
          "title": "\(titleInstruction)",
          "summary": "One-sentence summary of the day",
          "mood": "A single emoji representing the mood. Prefer specific objects (e.g., ☕️, 🐱, 🌧️) over generic faces if mentioned.",
          "content": "Full diary content in Markdown. Use ## for headers if needed. NO Title/Date at start.",
          "insights": "\(insightValueDescription)"
        }

        Content Guidelines:
        1. **First-Person Immersion**: Write strictly as "I". Never address the user as "you". Never mention "Wing", "AI", or "Assistant".
        2. **Handling Fragments**: Weave fragments into a smooth story. Do not list them.
        3. **Handling Photos**: If the input contains "[Photo]" or "[Image]" markers, simply IGNORE and REMOVE them to maintain text flow. Do not describe them.
        4. **Memory Usage**: If "Background Context (Implicit Knowledge)" is provided, treat it as the user's own existing knowledge. Use it to ensure continuity (e.g., knowing a friend's name without being told today), but NEVER say "According to records".
        5. **Formatting**: Use Markdown (bold **, lists -). NO emoji inside the 'content' field.
        6. **Natural Time & Date**: **NEVER** mention the exact calendar date (e.g., "Feb 16"). Use natural references like "This Monday" or just "Today". Convert timestamps (e.g., 09:30) into narrative flow (e.g., "In the morning").
        """
    }
    
    /// 根据 writingStyle 生成文风指令（使用本地化 Prompt）
    private func buildToneInstruction(writingStyle: WritingStyle, writingStylePrompt: String? = nil) -> String {
        switch writingStyle {
        case .custom:
            if let prompt = writingStylePrompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return prompt
            }
            return WritingStyle.prose.defaultPrompt
        default:
            return writingStyle.defaultPrompt
        }
    }
    
    private func buildTitleInstruction(style: TitleStyle, customPrompt: String? = nil) -> String {
        switch style {
        case .custom:
            if let prompt = customPrompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return prompt
            }
            return TitleStyle.abstract.defaultPrompt
        default:
            return style.defaultPrompt
        }
    }

    private func getMemorySystemInstruction(language: JournalLanguage = .auto) -> String {
        let languageInstruction: String
        switch language {
        case .auto: languageInstruction = "Output languages matching the input content."
        case .zh: languageInstruction = "Ensure all values (except standardized keys) are in Chinese (简体中文)."
        case .en: languageInstruction = "Ensure all values are in English."
        }

        return """
        Role: You are an expert Memory Archivist for a personal diary AI.
        Task: Extract structured memories from the user's diary entry to build a long-term knowledge base.
        Input: A single diary entry.
        Output: A JSON object with three categories of memories:

        1. semantic (Facts): Static facts about the user (e.g., names, locations, relationships, preferences).
           - key: Standardized attribute name (e.g., "user_name", "spouse_name", "current_city").
           - value: The fact value.
           - confidence: 0.8 to 1.0 (High confidence only).

        2. episodic (Events): Significant life events found in the entry.
           - event: Concise description of what happened.
           - date: Date string (YYYY-MM-DD). If not explicit, interpret from context (today is the entry date).
           - emotion: Dominant emotion (e.g., "Joyful", "Anxious").
           - context: Brief context or significance.

        3. procedural (Patterns): User behavioral patterns or interaction preferences inferred from the writing.
           - pattern: E.g., "Late night writing", "Short sentence style".
           - preference: E.g., "Likes harsh advice", "Prefers soothing tone".
           - trigger: What triggers this pattern (optional).

        Language Requirement: \(languageInstruction)
        Format: JSON ONLY. No markdown blocks.
        
        Example Output:
        {
          "semantic": [
            {"key": "user_name", "value": "Hans", "confidence": 0.9}
          ],
          "episodic": [
            {"event": "Completed Phase 8 development", "date": "2026-02-05", "emotion": "Accomplished", "context": "Work achievement"}
          ],
          "procedural": []
        }
        """
    }

    
    private func buildUserPrompt(from fragments: [RawFragment], memories: [String] = []) -> String {
        // 按时间戳排序，确保先后顺序正确
        let sortedFragments = fragments.sorted { $0.timestamp < $1.timestamp }
        
        let fragmentTexts = sortedFragments.map { fragment in
            let timeStr = Date(timeIntervalSince1970: TimeInterval(fragment.timestamp) / 1000).formatted(date: .omitted, time: .shortened)
            let imageMarker = fragment.type == .image ? "[Photo]" : ""
            return "[\(timeStr)] \(imageMarker) \(fragment.content)"
        }.joined(separator: "\n")
        
        let dateOfEntry: String
        if let firstFragment = sortedFragments.first {
            let date = Date(timeIntervalSince1970: TimeInterval(firstFragment.timestamp) / 1000)
            // 强制使用 ISO 8601 (YYYY-MM-DD) + 星期几
            let isoDateFormatter = DateFormatter()
            isoDateFormatter.dateFormat = "yyyy-MM-dd EEEE"
            isoDateFormatter.locale = Locale(identifier: "en_US_POSIX") // 确保格式固定
            dateOfEntry = isoDateFormatter.string(from: date)
        } else {
            let isoDateFormatter = DateFormatter()
            isoDateFormatter.dateFormat = "yyyy-MM-dd EEEE"
            isoDateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateOfEntry = isoDateFormatter.string(from: Date())
        }
        
        var prompt = """
        Context: \(dateOfEntry)
        User's fragments for today (in chronological order):
        
        \(fragmentTexts)
        """
        
        if !memories.isEmpty {
            prompt += "\n\nBackground Context (Implicit Knowledge):\n\n" + memories.joined(separator: "\n\n")
        }
        
        prompt += "\n\nSynthesize these fragments into a cohesive first-person narrative."
        return prompt
    }
    
    // MARK: - Request Builders
    
    private func buildOpenAICompatibleRequest(config: AIConfig, system: String, user: String) throws -> URLRequest {
        let baseURL: String
        if let customURL = config.baseURL, !customURL.isEmpty {
            baseURL = customURL
        } else if config.provider == .deepseek {
            baseURL = deepSeekBaseURL
        } else {
            baseURL = openAIBaseURL
        }
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
    
    // MARK: - JSON Mode Request Builders
    
    private func buildOpenAIJSONRequest(config: AIConfig, system: String, user: String) throws -> URLRequest {
        let baseURL: String
        if let customURL = config.baseURL, !customURL.isEmpty {
            baseURL = customURL
        } else if config.provider == .deepseek {
            baseURL = deepSeekBaseURL
        } else {
            baseURL = openAIBaseURL
        }
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
            "stream": false,
            "max_tokens": 4096,
            "response_format": ["type": "json_object"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
    
    private func buildGeminiJSONRequest(config: AIConfig, system: String, user: String) throws -> URLRequest {
        let model = config.model.isEmpty ? "gemini-2.5-flash" : config.model
        // 非流式：使用 generateContent 而非 streamGenerateContent
        let urlString = "\(geminiBaseURL)/models/\(model):generateContent?key=\(config.apiKey)"
        
        guard let url = URL(string: urlString) else { throw AIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
            ],
            "generationConfig": [
                "response_mime_type": "application/json"
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
    
    // MARK: - JSON Mode Parsers
    
    private func parseOpenAIJSONResponse(_ data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.parsingError
        }
        return content
    }
    
    private func parseGeminiJSONResponse(_ data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let contentObj = firstCandidate["content"] as? [String: Any],
              let parts = contentObj["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw AIError.parsingError
        }
        return text
    }
    
    /// 解析日记输出 JSON
    /// 使用 nonisolated 确保解码操作不受 actor 隔离限制
    nonisolated private func parseJournalOutput(_ rawContent: String) -> JournalOutput {
        // 清理可能的 Markdown 代码块包裹
        var cleanedContent = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedContent.hasPrefix("```json") {
            cleanedContent = cleanedContent.replacingOccurrences(of: "```json", with: "")
            cleanedContent = cleanedContent.replacingOccurrences(of: "```", with: "")
            cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 尝试解析 JSON
        guard let data = cleanedContent.data(using: .utf8),
              let output = try? JSONDecoder().decode(JournalOutput.self, from: data) else {
            // Fallback: 解析失败时返回"无题日记"
            print("⚠️ JSON 解析失败，使用 Fallback 模式")
            return JournalOutput.fallback(rawContent: cleanedContent).sanitized()
        }
        
        return output.sanitized()
    }
    
    /// 解析记忆输出 JSON
    nonisolated private func parseMemoryOutput(_ rawContent: String) -> MemoryExtractionResult {
        // 清理可能的 Markdown 代码块包裹
        var cleanedContent = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedContent.hasPrefix("```json") {
            cleanedContent = cleanedContent.replacingOccurrences(of: "```json", with: "")
            cleanedContent = cleanedContent.replacingOccurrences(of: "```", with: "")
            cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 尝试解析 JSON
        guard let data = cleanedContent.data(using: .utf8),
              let output = try? JSONDecoder().decode(MemoryExtractionResult.self, from: data) else {
            print("⚠️ Memory JSON 解析失败")
            return MemoryExtractionResult(semantic: [], episodic: [], procedural: [])
        }
        
        return output
    }
}
