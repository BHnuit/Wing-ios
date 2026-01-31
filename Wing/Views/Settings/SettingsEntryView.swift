//
//  SettingsEntryView.swift
//  Wing
//
//  Created on 2026-01-29.
//

import SwiftUI
import SwiftData

// MARK: - Validation State

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

// MARK: - Preset Models

/**
 * 预设模型列表
 */
enum PresetModels {
    static let models: [AiProvider: [String]] = [
        .gemini: ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-2.5-pro"],
        .openai: ["gpt-4o", "gpt-4o-mini", "o1", "o3-mini"],
        .deepseek: ["deepseek-chat", "deepseek-reasoner"],
        .custom: []
    ]
    
    static func defaultModel(for provider: AiProvider) -> String {
        models[provider]?.first ?? ""
    }
}

// MARK: - Settings Entry View

/**
 * 设置入口视图
 */
struct SettingsEntryView: View {
    @Bindable private var settingsManager = SettingsManager.shared
    
    @State private var apiKeyInput: String = ""
    @State private var isSavingKey: Bool = false
    @State private var showApiKey: Bool = false
    @State private var validationState: ValidationState = .idle
    @State private var isUpdatingProvider: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    StatsSection()
                    
                    if let settings = settingsManager.appSettings {
                        AIConfigSection(
                            settings: settings,
                            apiKeyInput: $apiKeyInput,
                            isSavingKey: $isSavingKey,
                            showApiKey: $showApiKey,
                            validationState: $validationState
                        )
                        
                        JournalLanguageSection(settings: settings)
                        
                        DataManagementSection()
                    } else {
                        ProgressView("Loading Settings...")
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("设置")
            .background(Color(.systemGroupedBackground))
            // 监听 Provider 切换
            .onChange(of: settingsManager.appSettings?.aiProvider) { _, newValue in
                guard let newValue = newValue else { return }
                isUpdatingProvider = true
                Task {
                    apiKeyInput = await SettingsManager.shared.getApiKey(for: newValue) ?? ""
                    
                    // 检查该 Provider 是否已验证过
                    if SettingsManager.shared.validatedProviders.contains(newValue) {
                        validationState = .valid
                    } else {
                        validationState = .idle
                    }
                    
                    // 延迟重置标志位，确保跳过 input 变更的副作用
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    isUpdatingProvider = false
                }
            }
            // 监听 API Key 输入变化
            .onChange(of: apiKeyInput) { _, _ in
                if !isUpdatingProvider {
                    validationState = .idle
                }
            }
        }
    }
}

// MARK: - Stats Section

struct StatsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("统计数据")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            HStack(spacing: 12) {
                StatCard(title: "已记录天数", value: "1", unit: "天")
                StatCard(title: "今日挥动", value: "0", unit: "次")
            }
            
            HStack(spacing: 12) {
                StatCard(title: "收集羽毛", value: "0", unit: "片")
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - AI Config Section

struct AIConfigSection: View {
    @Bindable var settings: AppSettings
    @Binding var apiKeyInput: String
    @Binding var isSavingKey: Bool
    @Binding var showApiKey: Bool
    @Binding var validationState: ValidationState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "cpu", iconColor: .blue, title: "模型配置", subtitle: "选择你的 AI 伙伴")
            
            VStack(spacing: 16) {
                ProviderPicker(settings: settings, validationState: $validationState)
                ModelPicker(settings: settings)
                APIKeyInput(
                    settings: settings,
                    apiKeyInput: $apiKeyInput,
                    isSavingKey: $isSavingKey,
                    showApiKey: $showApiKey,
                    validationState: $validationState
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding(.top)
    }
}

// MARK: - Provider Picker

struct ProviderPicker: View {
    @Bindable var settings: AppSettings
    @Binding var validationState: ValidationState
    
    var body: some View {
        Picker("AI 供应商", selection: Binding(
            get: { settings.aiProvider },
            set: { newProvider in
                settings.aiProvider = newProvider
                validationState = .idle
            }
        )) {
            Text("Gemini").tag(AiProvider.gemini)
            Text("OpenAI").tag(AiProvider.openai)
            Text("DeepSeek").tag(AiProvider.deepseek)
        }
        .pickerStyle(.segmented)
    }
}

// MARK: - Model Picker

struct ModelPicker: View {
    @Bindable var settings: AppSettings
    
    private var currentModel: String {
        settings.aiModels[settings.aiProvider] ?? PresetModels.defaultModel(for: settings.aiProvider)
    }
    
    private var availableModels: [String] {
        PresetModels.models[settings.aiProvider] ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("模型选择")
                .font(.caption)
                .foregroundStyle(.secondary)
            
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
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
    }
}

// MARK: - API Key Input

struct APIKeyInput: View {
    @Bindable var settings: AppSettings
    @Binding var apiKeyInput: String
    @Binding var isSavingKey: Bool
    @Binding var showApiKey: Bool
    @Binding var validationState: ValidationState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            APIKeyHeader(validationState: validationState)
            APIKeyTextField(apiKeyInput: $apiKeyInput, showApiKey: $showApiKey, validationState: $validationState)
            APIKeyButtons(
                settings: settings,
                apiKeyInput: $apiKeyInput,
                isSavingKey: $isSavingKey,
                validationState: $validationState
            )
        }
    }
}

// MARK: - API Key Header

struct APIKeyHeader: View {
    let validationState: ValidationState
    
    var body: some View {
        HStack {
            Text("API Key")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            ValidationStatusView(state: validationState)
        }
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

// MARK: - API Key Text Field

struct APIKeyTextField: View {
    @Binding var apiKeyInput: String
    @Binding var showApiKey: Bool
    @Binding var validationState: ValidationState
    
    var body: some View {
        HStack {
            Group {
                if showApiKey {
                    TextField("请输入 API Key", text: $apiKeyInput)
                } else {
                    SecureField("请输入 API Key", text: $apiKeyInput)
                }
            }
            .textFieldStyle(.roundedBorder)
            Button {
                showApiKey.toggle()
            } label: {
                Image(systemName: showApiKey ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - API Key Buttons

struct APIKeyButtons: View {
    @Bindable var settings: AppSettings
    @Binding var apiKeyInput: String
    @Binding var isSavingKey: Bool
    @Binding var validationState: ValidationState
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    await validateApiKey()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "network")
                    Text("验证连接")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .disabled(apiKeyInput.isEmpty || validationState == .validating)
            
            Button {
                Task {
                    await saveApiKey()
                }
            } label: {
                if isSavingKey {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "key.fill")
                        Text("保存至 Keychain")
                    }
                    .font(.caption)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSavingKey || apiKeyInput.isEmpty)
        }
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
            
            // 缓存验证状态
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

// MARK: - Journal Language Section

struct JournalLanguageSection: View {
    @Bindable var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "globe", iconColor: .purple, title: "日记语言", subtitle: "设置 AI 生成日记的语言")
            
            VStack(spacing: 12) {
                Picker("日记语言", selection: Binding(
                    get: { settings.journalLanguage },
                    set: { settings.journalLanguage = $0 }
                )) {
                    ForEach(JournalLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                
                Text("自动检测：根据你的碎片内容语言自动选择")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .padding(8)
                .background(iconColor.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Data Management Section

struct DataManagementSection: View {
    @Environment(\.modelContext) private var modelContext
    @State private var exportItem: ExportItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "externaldrive", iconColor: .green, title: "数据管理", subtitle: "备份与导出")
            
            VStack(spacing: 12) {
                Button {
                    Task {
                        await exportJSON()
                    }
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("导出完整备份 (JSON)")
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
                
            Text("完整备份包含所有图片和历史记录，可用于恢复数据。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .sheet(item: $exportItem) { item in
            ShareSheet(activityItems: [item.url])
                .presentationDetents([.medium, .large])
        }
    }
    
    // MARK: - Export Logic
    
    private func exportJSON() async {
        do {
            let fileURL = try await DataExportService.shared.exportJSON(context: modelContext)
            exportItem = ExportItem(url: fileURL)
        } catch {
            print("Export JSON failed: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsEntryView()
        .modelContainer(for: [AppSettings.self, DailySession.self], inMemory: true)
        .onAppear {
            SettingsManager.shared.initialize(with: try! ModelContainer(for: AppSettings.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        }
}
