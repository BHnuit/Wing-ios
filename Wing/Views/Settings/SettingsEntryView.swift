//
//  SettingsEntryView.swift
//  Wing
//
//  Created on 2026-01-29.
//

import SwiftUI
import SwiftData

/**
 * 设置入口视图
 * 包含：
 * 1. 顶部统计卡片（参考 Web 设计）
 * 2. 模型配置卡片（AI 供应商、模型、Key）
 * 3. 其他非核心设置入口（占位）
 */
struct SettingsEntryView: View {
    @Bindable private var settingsManager = SettingsManager.shared
    
    @State private var apiKeyInput: String = ""
    @State private var isSavingKey: Bool = false
    @State private var showApiKey: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - 1. 统计卡片 (Stats)
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
                    
                    // MARK: - 2. AI 模型配置 (AI Config)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundStyle(.blue)
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading) {
                                Text("模型配置")
                                    .font(.headline)
                                Text("选择你的 AI 伙伴")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        if let settings = settingsManager.appSettings {
                            VStack(spacing: 16) {
                                // Provider Picker
                                Picker("AI 供应商", selection: Binding(
                                    get: { settings.aiProvider },
                                    set: { settings.aiProvider = $0 }
                                )) {
                                    Text("Gemini").tag(AiProvider.gemini)
                                    Text("OpenAI").tag(AiProvider.openai)
                                    Text("DeepSeek").tag(AiProvider.deepseek)
                                }
                                .pickerStyle(.segmented)
                                
                                // Model Name
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("模型名称")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    TextField("例如: gemini-2.5-flash", text: Binding(
                                        get: { settings.aiModels[settings.aiProvider] ?? "" },
                                        set: { newValue in
                                            var current = settings.aiModels
                                            current[settings.aiProvider] = newValue
                                            settings.aiModels = current
                                        }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                }
                                
                                // API Key (Keychain Managed)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("API Key")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    HStack {
                                        if showApiKey {
                                            TextField("请输入 API Key", text: $apiKeyInput)
                                                .textFieldStyle(.roundedBorder)
                                        } else {
                                            SecureField("请输入 API Key", text: $apiKeyInput)
                                                .textFieldStyle(.roundedBorder)
                                        }
                                        
                                        Button {
                                            showApiKey.toggle()
                                        } label: {
                                            Image(systemName: showApiKey ? "eye.slash" : "eye")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    Button {
                                        Task {
                                            isSavingKey = true
                                            await settingsManager.setApiKey(apiKeyInput, for: settings.aiProvider)
                                            try? await Task.sleep(nanoseconds: 500_000_000) // fake delay
                                            isSavingKey = false
                                        }
                                    } label: {
                                        if isSavingKey {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Text("保存密钥至 Keychain")
                                                .font(.caption)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isSavingKey)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            
                            // Load Key on Provider Change
                            .onChange(of: settings.aiProvider, initial: true) { oldValue, newValue in
                                Task {
                                    apiKeyInput = await settingsManager.getApiKey(for: newValue) ?? ""
                                }
                            }
                        } else {
                            ProgressView("Loading Settings...")
                        }
                    }
                    .padding(.top)
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("设置")
            .background(Color(.systemGroupedBackground))
        }
    }
}

// 简单的统计卡片组件
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

#Preview {
    SettingsEntryView()
        .modelContainer(for: AppSettings.self, inMemory: true)
        .onAppear {
            // Preview Mock Init
            SettingsManager.shared.initialize(with: try! ModelContainer(for: AppSettings.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        }
}
