//
//  AIServiceDebugView.swift
//  Wing
//
//  Created on 2026-01-29.
//

import SwiftUI

/**
 * AI 服务测试视图 (Smoke Test)
 * 用于手动验证 AIService 的流式生成能力。
 */
struct AIServiceDebugView: View {
    @State private var apiKey: String = ""
    @State private var generatedText: String = ""
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String?
    @State private var selectedProvider: AiProvider = .gemini
    
    // 从 Keychain 读取
    let keychain = KeychainHelper.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("AI Service Smoke Test")
                .font(.title2)
                .bold()
            
            // 配置区域
            VStack(alignment: .leading) {
                Picker("Provider", selection: $selectedProvider) {
                    Text("Gemini").tag(AiProvider.gemini)
                    Text("OpenAI").tag(AiProvider.openai)
                    Text("DeepSeek").tag(AiProvider.deepseek)
                }
                .pickerStyle(.segmented)
                
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .disabled(isGenerating)
                
                Text("若 Keychain 中有值将优先使用，此处留空即可。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // 操作区域
            Button(action: startGeneration) {
                if isGenerating {
                    ProgressView()
                        .padding(.horizontal)
                } else {
                    Text("开始流式生成")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isGenerating)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            
            // 输出展示区域
            ScrollView {
                Text(generatedText)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .background(Color(.systemBackground))
            .border(Color(.separator))
            
            Spacer()
        }
        .padding()
        .task {
            // 尝试加载预存 Key
            if let savedKey = try? await keychain.loadString(for: "gemini_api_key") {
                self.apiKey = savedKey
                print("Loaded key from Keychain")
            }
        }
    }
    
    private func startGeneration() {
        guard !apiKey.isEmpty else {
            errorMessage = "请输入 API Key"
            return
        }
        
        isGenerating = true
        generatedText = ""
        errorMessage = nil
        
        // 模拟今日碎片
        let mockFragments = [
            RawFragment(content: "今天天气不错，去公园散步了。", timestamp: Int64(Date().timeIntervalSince1970 * 1000), type: .text),
            RawFragment(content: "喝了一杯拿铁，味道很香。", timestamp: Int64(Date().timeIntervalSince1970 * 1000), type: .text),
            RawFragment(content: "晚上看了一部电影，叫做《星际穿越》，非常感人。", timestamp: Int64(Date().timeIntervalSince1970 * 1000), type: .text)
        ]
        
        var model = ""
        var baseURL: String? = nil
        
        switch selectedProvider {
        case .gemini:
            model = "gemini-2.5-flash"
        case .openai:
            model = "gpt-4o"
        case .deepseek:
            model = "deepseek-chat"
            baseURL = "https://api.deepseek.com"
        default:
            model = "gpt-4o"
        }
        
        let config = AIConfig(
            provider: selectedProvider,
            model: model,
            apiKey: apiKey,
            baseURL: baseURL
        )
        
        Task {
            do {
                let stream = await AIService.shared.synthesizeJournalStream(fragments: mockFragments, config: config)
                
                for try await chunk in stream {
                    // 实现平滑的打字机效果：逐字符显示，而非整块显示
                    for char in chunk {
                        await MainActor.run {
                            generatedText.append(char)
                        }
                        // 约 30ms 一个字，模拟真实打字感
                        try await Task.sleep(nanoseconds: 30_000_000)
                    }
                }
                
                await MainActor.run {
                    generatedText += "\n\n[DONE]"
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error: \(error.localizedDescription)"
                    isGenerating = false
                }
            }
        }
    }
}

#Preview {
    AIServiceDebugView()
}
