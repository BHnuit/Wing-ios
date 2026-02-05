//
//  SettingsAIView.swift
//  Wing
//
//  Created on 2026-02-05.
//

import SwiftUI
import SwiftData

struct SettingsAIView: View {
    @Bindable var settingsManager = SettingsManager.shared
    
    @State private var apiKeyInput: String = ""
    @State private var isSavingKey: Bool = false
    @State private var showApiKey: Bool = false
    @State private var validationState: ValidationState = .idle
    @State private var isUpdatingProvider: Bool = false
    
    var body: some View {
        Form {
            if let settings = settingsManager.appSettings {
                Section {
                    ProviderPicker(settings: settings, validationState: $validationState)
                    ModelPicker(settings: settings)
                } header: {
                    Text("服务商与模型")
                }
                
                Section {
                    APIKeyInput(
                        settings: settings,
                        apiKeyInput: $apiKeyInput,
                        isSavingKey: $isSavingKey,
                        showApiKey: $showApiKey,
                        validationState: $validationState
                    )
                } header: {
                    Text("凭证配置")
                } footer: {
                    Text("API Key 将安全存储在 Keychain 中，不会上传到任何第三方服务器。")
                }
                
                Section {
                    Toggle("启用长期记忆", isOn: Binding(
                        get: { settingsManager.appSettings?.enableLongTermMemory ?? false },
                        set: { newValue in
                            settingsManager.appSettings?.enableLongTermMemory = newValue
                            // Explicitly save to ensure persistence
                            try? settingsManager.modelContext?.save()
                        }
                    ))
                } header: {
                    Text("高级功能")
                } footer: {
                    Text("启用后，Wing 将从您的日记中提取长期记忆，用于增强后续的对话体验。")
                }
            }
        }
        .navigationTitle("模型配置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let provider = settingsManager.appSettings?.aiProvider {
                Task {
                    apiKeyInput = await SettingsManager.shared.getApiKey(for: provider) ?? ""
                    checkValidationState(for: provider)
                }
            }
        }
        .onChange(of: settingsManager.appSettings?.aiProvider) { _, newValue in
            guard let newValue = newValue else { return }
            isUpdatingProvider = true
            Task {
                apiKeyInput = await SettingsManager.shared.getApiKey(for: newValue) ?? ""
                checkValidationState(for: newValue)
                
                try? await Task.sleep(nanoseconds: 200_000_000)
                isUpdatingProvider = false
            }
        }
        .onChange(of: apiKeyInput) { _, _ in
            if !isUpdatingProvider {
                validationState = .idle
            }
        }
    }
    
    private func checkValidationState(for provider: AiProvider) {
        if SettingsManager.shared.validatedProviders.contains(provider) {
            validationState = .valid
        } else {
            validationState = .idle
        }
    }
}

// MARK: - Models

/**
 * API Key 验证状态
 */
enum ValidationState: Equatable {
    case idle        // 未验证
    case validating  // 验证中 ⏳
    case valid       // 有效 ✅
    case invalid(String)  // 无效 ❌ + 错误信息
    
    var icon: String {
        switch self {
        case .idle: return "questionmark.circle"
        case .validating: return "arrow.clockwise"
        case .valid: return "checkmark.circle.fill"
        case .invalid: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .idle: return .secondary
        case .validating: return .orange
        case .valid: return .green
        case .invalid: return .red
        }
    }
    
    static func == (lhs: ValidationState, rhs: ValidationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.validating, .validating), (.valid, .valid):
            return true
        case (.invalid(let l), .invalid(let r)):
            return l == r
        default:
            return false
        }
    }
}

/**
 * 预设模型列表
 */
enum PresetModels {
    static let models: [AiProvider: [String]] = [
        .gemini: ["gemini-2.0-flash", "gemini-1.5-flash", "gemini-1.5-pro"],
        .openai: ["gpt-4o", "gpt-4o-mini", "o1", "o3-mini"],
        .deepseek: ["deepseek-chat", "deepseek-reasoner"],
        .custom: []
    ]
    
    static func defaultModel(for provider: AiProvider) -> String {
        models[provider]?.first ?? ""
    }
}

// MARK: - Validation Status View

struct ValidationStatusView: View {
    let state: ValidationState
    
    var body: some View {
        HStack(spacing: 4) {
            if case .validating = state {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Image(systemName: state.icon)
                    .foregroundStyle(state.color)
            }
            
            statusText
        }
    }
    
    @ViewBuilder
    private var statusText: some View {
        switch state {
        case .idle:
            Text("未验证")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .validating:
            Text("验证中...")
                .font(.caption2)
                .foregroundStyle(.orange)
        case .valid:
            Text("连接成功")
                .font(.caption2)
                .foregroundStyle(.green)
        case .invalid(let message):
            Text(message)
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }
}

// MARK: - Subviews (Extracted from SettingsEntryView)

struct ProviderPicker: View {
    @Bindable var settings: AppSettings
    @Binding var validationState: ValidationState
    
    var body: some View {
        Picker("AI 服务商", selection: Binding(
            get: { settings.aiProvider },
            set: { newProvider in
                settings.aiProvider = newProvider
                validationState = .idle
            }
        )) {
            Text("Gemini").tag(AiProvider.gemini)
            Text("OpenAI").tag(AiProvider.openai)
            Text("DeepSeek").tag(AiProvider.deepseek)
            Text("Custom").tag(AiProvider.custom)
        }
    }
}

struct ModelPicker: View {
    @Bindable var settings: AppSettings
    
    private var currentModel: String {
        settings.aiModels[settings.aiProvider] ?? PresetModels.defaultModel(for: settings.aiProvider)
    }
    
    private var availableModels: [String] {
        PresetModels.models[settings.aiProvider] ?? []
    }
    
    var body: some View {
        if settings.aiProvider == .custom {
            TextField("模型名称", text: Binding(
                get: { currentModel },
                set: { newValue in
                    var current = settings.aiModels
                    current[settings.aiProvider] = newValue
                    settings.aiModels = current
                }
            ))
        } else {
            Picker("模型", selection: Binding(
                get: { currentModel },
                set: { newValue in
                    var current = settings.aiModels
                    current[settings.aiProvider] = newValue
                    settings.aiModels = current
                }
            )) {
                ForEach(availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
                
                // 允许用户输入自定义模型名即使在非 Custom 模式下 (针对新模型)
                Text("自定义...").tag("custom")
            }
        }
    }
}

struct APIKeyInput: View {
    @Bindable var settings: AppSettings
    @Binding var apiKeyInput: String
    @Binding var isSavingKey: Bool
    @Binding var showApiKey: Bool
    @Binding var validationState: ValidationState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if showApiKey {
                    TextField("API Key", text: $apiKeyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField("API Key", text: $apiKeyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Button {
                    showApiKey.toggle()
                } label: {
                    Image(systemName: showApiKey ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack {
                ValidationStatusView(state: validationState)
                
                Spacer()
                
                Button("验证连接") {
                    Task {
                        await validateApiKey()
                    }
                }
                .disabled(apiKeyInput.isEmpty || validationState == .validating)
                
                Button("保存") {
                    Task {
                        await saveApiKey()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKeyInput.isEmpty || isSavingKey)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func validateApiKey() async {
        validationState = .validating
        
        let model = settings.aiModels[settings.aiProvider] ?? PresetModels.defaultModel(for: settings.aiProvider)
        let config = AIConfig(
            provider: settings.aiProvider,
            model: model,
            apiKey: apiKeyInput,
            baseURL: settings.aiBaseUrl
        )
        
        do {
            _ = try await AIService.shared.validateConnection(config: config)
            validationState = .valid
            
            SettingsManager.shared.validatedProviders.insert(settings.aiProvider)
            
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } catch let error as AIError {
            validationState = .invalid(error.errorDescription ?? "验证失败")
        } catch {
            validationState = .invalid("网络错误")
        }
    }
    
    private func saveApiKey() async {
        isSavingKey = true
        await SettingsManager.shared.setApiKey(apiKeyInput, for: settings.aiProvider)
        try? await Task.sleep(nanoseconds: 300_000_000)
        isSavingKey = false
    }
}

// 借用 SettingsEntryView 中的 ValidationState 和 PresetModels
// 如果需要在多处使用，建议移到单独的 Models 文件，这里暂时复用或假定已移动
