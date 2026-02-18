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
                    Text(L("settings.ai.section.provider"))
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
                    Text(L("settings.ai.section.credential"))
                } footer: {
                    Text(L("settings.ai.section.credential.footer"))
                }
                
                // 文风与自定义 Prompt
                Section {
                    TitleStyleSectionView(settings: settings, settingsManager: settingsManager)
                    WritingStyleSectionView(settings: settings, settingsManager: settingsManager)
                    InsightStyleSectionView(settings: settings, settingsManager: settingsManager)

                } header: {
                    Text(L("settings.ai.section.personalization"))
                } footer: {
                    Text(L("settings.ai.section.personalization.footer"))
                }
                
                Section {
                    Toggle(L("settings.ai.longTermMemory"), isOn: Binding(
                        get: { settingsManager.appSettings?.enableLongTermMemory ?? false },
                        set: { newValue in
                            settingsManager.appSettings?.enableLongTermMemory = newValue
                            // Explicitly save to ensure persistence
                            try? settingsManager.modelContext?.save()
                        }
                    ))
                } header: {
                    Text(L("settings.ai.section.advanced"))
                } footer: {
                    Text(L("settings.ai.section.advanced.footer"))
                }
            }
        }
        .navigationTitle(L("settings.ai.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let provider = settingsManager.appSettings?.aiProvider {
                isUpdatingProvider = true // 防止加载 Key 时触发 onChange 重置验证状态
                Task {
                    apiKeyInput = await SettingsManager.shared.getApiKey(for: provider) ?? ""
                    checkValidationState(for: provider)
                    
                    // 如果 insightPrompt 为空，预填默认值以便用户编辑
                    if settingsManager.appSettings?.insightPrompt == nil {
                        settingsManager.appSettings?.insightPrompt = AppSettings.defaultInsightPrompt
                    }
                    
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    isUpdatingProvider = false
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
        case .idle: return "questionmark.circle" // Revert
        case .validating: return "arrow.clockwise" // Revert
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
        .gemini: ["gemini-3-pro", "gemini-3-flash", "gemini-2.5-flash-lite", "gemini-2.0-flash"],
        .openai: ["gpt-5.2", "gpt-5", "gpt-4o"],
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
            Text(L("settings.ai.status.idle"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .validating:
            Text(L("settings.ai.status.validating"))
                .font(.caption2)
                .foregroundStyle(.orange)
        case .valid:
            Text(L("settings.ai.status.valid"))
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
        Picker(L("settings.ai.provider"), selection: Binding(
            get: { settings.aiProvider },
            set: { newProvider in
                settings.aiProvider = newProvider
                validationState = .idle
                // 显式保存更改
                try? SettingsManager.shared.modelContext?.save()
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
            TextField(L("settings.ai.modelName"), text: Binding(
                get: { currentModel },
                set: { newValue in
                    var current = settings.aiModels
                    current[settings.aiProvider] = newValue
                    settings.aiModels = current
                    try? SettingsManager.shared.modelContext?.save()
                }
            ))
        } else {
            Picker(L("settings.ai.model"), selection: Binding(
                get: { currentModel },
                set: { newValue in
                    var current = settings.aiModels
                    current[settings.aiProvider] = newValue
                    settings.aiModels = current
                    try? SettingsManager.shared.modelContext?.save()
                }
            )) {
                ForEach(availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
                
                // 允许用户输入自定义模型名即使在非 Custom 模式下 (针对新模型)
                Text(L("settings.ai.custom")).tag("custom")
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
                    Image(systemName: showApiKey ? "eye.slash" : "eye") // Revert
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack {
                ValidationStatusView(state: validationState)
                
                Spacer()
                
                Button(L("settings.ai.validate")) {
                    Task {
                        await validateApiKey()
                    }
                }
                .disabled(apiKeyInput.isEmpty || validationState == .validating)
                
                Button(L("settings.ai.save")) {
                    Task {
                        await saveApiKey()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKeyInput.isEmpty || isSavingKey)
            }
        }
        .padding(.vertical, 4)
        // 使用 borderless 样式避免在 Form 中点击冲突
        .buttonStyle(.borderless)
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
            validationState = .invalid(error.errorDescription ?? L("settings.ai.status.failed"))
        } catch {
            validationState = .invalid(L("settings.ai.status.networkError"))
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

struct TitleStyleSectionView: View {
    @Bindable var settings: AppSettings
    var settingsManager: SettingsManager
    
    var body: some View {
        Group {
            Picker(L("settings.ai.titleStyle"), selection: Binding(
                get: { settings.titleStyle },
                set: { newValue in
                    settings.titleStyle = newValue
                    try? settingsManager.modelContext?.save()
                }
            )) {
                ForEach(TitleStyle.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(settings.titleStyle == .custom ? L("settings.ai.titleStylePrompt") : L("settings.ai.titleStyle.preview"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if settings.titleStyle == .custom {
                    TextEditor(text: Binding(
                        get: { settings.titleStylePrompt ?? "" },
                        set: { newValue in
                            settings.titleStylePrompt = newValue
                            try? settingsManager.modelContext?.save()
                        }
                    ))
                    .frame(minHeight: 80)
                    .font(.body)
                    .overlay(
                        Group {
                            if (settings.titleStylePrompt ?? "").isEmpty {
                                Text(L("settings.ai.titleStylePrompt.placeholder"))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .topLeading
                    )
                } else {
                    Text(settings.titleStyle.defaultPrompt)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(8)
                }
            }
        }
    }
}

struct WritingStyleSectionView: View {
    @Bindable var settings: AppSettings
    var settingsManager: SettingsManager
    
    var body: some View {
        Group {
            Picker(L("settings.ai.writingStyle"), selection: Binding(
                get: { settings.writingStyle },
                set: { newValue in
                    settings.writingStyle = newValue
                    try? settingsManager.modelContext?.save()
                }
            )) {
                Text(L("settings.ai.writingStyle.letter")).tag(WritingStyle.letter)
                Text(L("settings.ai.writingStyle.prose")).tag(WritingStyle.prose)
                Text(L("settings.ai.writingStyle.report")).tag(WritingStyle.report)
                Text(L("settings.ai.writingStyle.custom")).tag(WritingStyle.custom)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(settings.writingStyle == .custom ? L("settings.ai.writingStylePrompt") : L("settings.ai.writingStyle.preview"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if settings.writingStyle == .custom {
                    TextEditor(text: Binding(
                        get: { settings.writingStylePrompt ?? "" },
                        set: { newValue in
                            settings.writingStylePrompt = newValue
                            try? settingsManager.modelContext?.save()
                        }
                    ))
                    .frame(minHeight: 80)
                    .font(.body)
                    .overlay(
                        Group {
                            if (settings.writingStylePrompt ?? "").isEmpty {
                                Text(L("settings.ai.writingStylePrompt.placeholder"))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .topLeading
                    )
                } else {
                    Text(settings.writingStyle.defaultPrompt)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(8)
                }
            }
        }
    }
}

struct InsightStyleSectionView: View {
    @Bindable var settings: AppSettings
    var settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("settings.ai.insightPrompt"))
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: Binding(
                get: { settings.insightPrompt ?? "" },
                set: { newValue in
                    settings.insightPrompt = newValue.isEmpty ? nil : newValue
                    try? settingsManager.modelContext?.save()
                }
            ))
            .frame(minHeight: 60)
            .font(.body)
            .overlay(
                Group {
                    if (settings.insightPrompt ?? "").isEmpty {
                        Text(L("settings.ai.insightPrompt.placeholder"))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                },
                alignment: .topLeading
            )
        }
    }
}
