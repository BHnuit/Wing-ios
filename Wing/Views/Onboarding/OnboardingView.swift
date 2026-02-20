//
//  OnboardingView.swift
//  Wing
//
//  Created on 2026-02-20.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    
    @Environment(SettingsManager.self) private var settingsManager
    
    @State private var currentPage = 0
    private let totalPages = 4 // 1 Intro + 2 Animations + 1 Config
    
    // Configurations for Slide 4
    @State private var tempProvider: AiProvider = .openai
    @State private var tempApiKey: String = ""
    @State private var tempDiaryStyle: OnboardingDiaryStyle = .letter
    
    @State private var showApiKey: Bool = false
    @State private var validationState: ValidationState = .idle

    
    var body: some View {
        ZStack {
            // 背景沉浸感
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
            VStack {
                Spacer()
                
                TabView(selection: $currentPage) {
                    // Slide 1
                    VStack(spacing: 20) {
                        WingLogoAnimationView()
                            .padding(.bottom, 10)
                        
                        Text(slide1Title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(String(localized: "onboarding.slide1.desc"))
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                            .lineSpacing(6)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .tag(0)
                    
                    // Slide 2
                    VStack(spacing: 20) {
                        SynthesisAnimationView()
                        
                        Text(String(localized: "onboarding.slide2.title"))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(slide2Desc)
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                            .lineSpacing(6)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .tag(1)
                    
                    // Slide 3
                    VStack(spacing: 20) {
                        MemoryGrowthAnimationView()
                        
                        Text(slide3Title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(String(localized: "onboarding.slide3.desc"))
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                            .lineSpacing(6)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .tag(2)
                    
                    // Slide 4: Configuration
                    VStack(spacing: 28) {
                        Text(String(localized: "onboarding.slide4.title"))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.top, 10)
                        
                        // 区块一：AI 模型选择
                        VStack(alignment: .leading, spacing: 16) {
                            Text(String(localized: "onboarding.slide4.model"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                ModelSelectButton(title: "OpenAI", isSelected: tempProvider == .openai) { tempProvider = .openai }
                                ModelSelectButton(title: "Gemini", isSelected: tempProvider == .gemini) { tempProvider = .gemini }
                                ModelSelectButton(title: "DeepSeek", isSelected: tempProvider == .deepseek) { tempProvider = .deepseek }
                            }
                            
                            
                            // API Key 输入框 (Liquid Glass 风格)
                            VStack(spacing: 0) {
                                HStack {
                                    if showApiKey {
                                        TextField(String(localized: "onboarding.slide4.apiKey.placeholder"), text: $tempApiKey)
                                    } else {
                                        SecureField(String(localized: "onboarding.slide4.apiKey.placeholder"), text: $tempApiKey)
                                    }
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .overlay(
                                    HStack {
                                        Spacer()
                                        Button {
                                            showApiKey.toggle()
                                        } label: {
                                            Image(systemName: showApiKey ? "eye.slash" : "eye")
                                                .foregroundColor(.secondary)
                                                .padding(.trailing, 16)
                                        }
                                    }
                                )
                                
                                Divider()
                                    .padding(.leading, 16)
                                
                                HStack {
                                    ValidationStatusView(state: validationState)
                                    Spacer()
                                    Button(String(localized: "settings.ai.validate")) {
                                        Task {
                                            await validateApiKey()
                                        }
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(validationState == .validating || tempApiKey.isEmpty ? Color.secondary.opacity(0.1) : Color.accentColor.opacity(0.15))
                                    .foregroundColor(validationState == .validating || tempApiKey.isEmpty ? .secondary : .accentColor)
                                    .cornerRadius(10)
                                    .disabled(tempApiKey.isEmpty || validationState == .validating)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.black.opacity(0.04), radius: 15, y: 5)
                            .overlay( // 轻微磨砂玻璃边缘高光
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                            )
                            
                            HStack(spacing: 4) {
                                Text(String(localized: "onboarding.slide4.apiKey.fetch.prefix"))
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(uiColor: .tertiaryLabel))
                                Link(destination: URL(string: apiKeyURL(for: tempProvider))!) {
                                    HStack(spacing: 2) {
                                        Text(String(format: String(localized: "onboarding.slide4.apiKey.fetch.action"), providerName(for: tempProvider)))
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.accentColor)
                                }
                                Spacer()
                            }
                            .padding(.top, 4)
                            .padding(.horizontal, 4)
                        }
                        
                        // 区块二：日记风格选择
                        VStack(alignment: .leading, spacing: 16) {
                            Text(String(localized: "onboarding.slide4.style"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 12) {
                                ForEach(OnboardingDiaryStyle.allCases, id: \.self) { style in
                                    StyleSelectButton(style: style, isSelected: tempDiaryStyle == style) {
                                        tempDiaryStyle = style
                                    }
                                }
                            }
                        }
                        
                        // 动态注释
                        VStack(spacing: 6) {
                            Text(dynamicStyleDescription)
                            .font(.system(size: 13))
                            
                            Text(String(localized: "onboarding.slide4.dynamic.notice"))
                                .font(.system(size: 12))
                                .foregroundColor(Color(uiColor: .tertiaryLabel))
                        }
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // 隐藏系统圆点，我们自定义
                .onChange(of: tempProvider) { _, _ in
                    validationState = .idle
                }
                .onChange(of: tempApiKey) { _, _ in
                    validationState = .idle
                }
                
                Spacer()
                
                // 翻页和操作区
                VStack(spacing: 24) {
                    // 自定义圆点指示器
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? Color.accentColor : Color(uiColor: .separator))
                                .frame(width: 8, height: 8)
                                .scaleEffect(currentPage == index ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }
                    
                    // 按钮组
                    if currentPage == totalPages - 1 {
                        VStack(spacing: 16) {
                            Button {
                                completeOnboarding()
                            } label: {
                                Text(String(localized: "onboarding.button.start"))
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        Capsule()
                                            .fill(Color.accentColor.opacity(0.8))
                                            .background(.ultraThinMaterial, in: Capsule())
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                    )
                                    .shadow(color: Color.accentColor.opacity(0.4), radius: 15, y: 8)
                            }
                            
                            Button {
                                skipConfiguration()
                            } label: {
                                Text(String(localized: "onboarding.button.skip"))
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentPage += 1
                            }
                        } label: {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.8))
                                        .background(.ultraThinMaterial, in: Circle())
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                )
                                .shadow(color: Color.accentColor.opacity(0.4), radius: 10, y: 5)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.bottom, 60)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)
            }
        }
    }
    
    // MARK: - Highlighted Texts
    private func highlightedText(_ text: String, keywords: [String]) -> AttributedString {
        var attrString = AttributedString(text)
        for keyword in keywords {
            if let range = attrString.range(of: keyword) {
                attrString[range].foregroundColor = .accentColor
            }
        }
        return attrString
    }
    
    private var slide1Title: AttributedString {
        highlightedText(String(localized: "onboarding.slide1.title"), keywords: ["Wing"])
    }
    
    private var slide2Desc: AttributedString {
        highlightedText(String(localized: "onboarding.slide2.desc"), keywords: ["长按记录键", "Long-press the record button", "記録ボタンを長押し"])
    }
    
    private var slide3Title: AttributedString {
        highlightedText(String(localized: "onboarding.slide3.title"), keywords: ["记忆", "Memories", "記憶"])
    }
    
    /// iOS 26 不再支持 Text + Text 拼接，改用 AttributedString 实现多色文本
    private var dynamicStyleDescription: AttributedString {
        let accentColor = UIColor.tintColor
        let secondaryColor = UIColor.secondaryLabel
        
        var result = AttributedString()
        
        var prefix = AttributedString(String(localized: "onboarding.slide4.dynamic.prefix"))
        prefix.foregroundColor = Color(uiColor: secondaryColor)
        result.append(prefix)
        
        var titleType = AttributedString(tempDiaryStyle.titleType)
        titleType.foregroundColor = Color(uiColor: accentColor)
        result.append(titleType)
        
        var titleAnd = AttributedString(String(localized: "onboarding.slide4.dynamic.titleAnd"))
        titleAnd.foregroundColor = Color(uiColor: secondaryColor)
        result.append(titleAnd)
        
        var writingType = AttributedString(tempDiaryStyle.writingType)
        writingType.foregroundColor = Color(uiColor: accentColor)
        result.append(writingType)
        
        var suffix = AttributedString(String(localized: "onboarding.slide4.dynamic.suffix"))
        suffix.foregroundColor = Color(uiColor: secondaryColor)
        result.append(suffix)
        
        return result
    }
    
    private func completeOnboarding() {
        // Save Config to SettingsManager
        Task {
            if let settings = settingsManager.appSettings {
                settings.aiProvider = tempProvider
                settings.titleStyle = tempDiaryStyle.mappedTitleStyle
                settings.writingStyle = tempDiaryStyle.mappedWritingStyle
                try? settingsManager.modelContext?.save()
            }
            
            if !tempApiKey.isEmpty {
                await settingsManager.setApiKey(tempApiKey, for: tempProvider)
            }
            
            // 标记完成，触发 RootView 切换
            await MainActor.run {
                withAnimation {
                    hasCompletedOnboarding = true
                }
            }
            
            // 尝试生成第一条记录
            do {
                try OnboardingService.shared.createWelcomeEntryIfNeeded(context: modelContext)
            } catch {
                print("Failed to create welcome entry: \(error)")
            }
        }
    }
    
    private func skipConfiguration() {
        // 跳过不保存 Config
        withAnimation {
            hasCompletedOnboarding = true
        }
        
        do {
            try OnboardingService.shared.createWelcomeEntryIfNeeded(context: modelContext)
        } catch {
            print("Failed to create welcome entry: \(error)")
        }
    }
    // Helper function for URLs
    private func apiKeyURL(for provider: AiProvider) -> String {
        switch provider {
        case .openai: return "https://platform.openai.com/api-keys"
        case .gemini: return "https://aistudio.google.com/app/apikey"
        case .deepseek: return "https://platform.deepseek.com/api_keys"
        default: return "https://google.com"
        }
    }
    
    private func validateApiKey() async {
        validationState = .validating
        let model = tempProvider == .custom ? "" : (PresetModels.defaultModel(for: tempProvider))
        let config = AIConfig(
            provider: tempProvider,
            model: model,
            apiKey: tempApiKey,
            baseURL: ""
        )
        
        do {
            _ = try await AIService.shared.validateConnection(config: config)
            validationState = .valid
            SettingsManager.shared.validatedProviders.insert(tempProvider)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } catch let error as AIError {
            validationState = .invalid(error.errorDescription ?? String(localized: "settings.ai.status.failed"))
        } catch {
            validationState = .invalid(String(localized: "settings.ai.status.networkError"))
        }
    }
    
    private func providerName(for provider: AiProvider) -> String {
        switch provider {
        case .openai: return "OpenAI"
        case .gemini: return "Gemini"
        case .deepseek: return "DeepSeek"
        default: return "Platform"
        }
    }
}

enum OnboardingDiaryStyle: CaseIterable {
    case letter, prose, report
    
    var displayName: String {
        switch self {
        case .letter: return String(localized: "diary.style.letter")
        case .prose: return String(localized: "diary.style.prose")
        case .report: return String(localized: "diary.style.report")
        }
    }
    
    var titleType: String {
        switch self {
        case .letter: return String(localized: "diary.title.letter")
        case .prose: return String(localized: "diary.title.prose")
        case .report: return String(localized: "diary.title.report")
        }
    }
    
    var writingType: String {
        switch self {
        case .letter: return String(localized: "diary.writing.letter")
        case .prose: return String(localized: "diary.writing.prose")
        case .report: return String(localized: "diary.writing.report")
        }
    }
    
    var mappedTitleStyle: TitleStyle {
        switch self {
        case .letter: return .dateBased
        case .prose: return .abstract
        case .report: return .summary
        }
    }
    
    var mappedWritingStyle: WritingStyle {
        switch self {
        case .letter: return .letter
        case .prose: return .prose
        case .report: return .report
        }
    }
}

struct ModelSelectButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .accentColor : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                )
        }
    }
}

struct StyleSelectButton: View {
    let style: OnboardingDiaryStyle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(style.displayName)
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .accentColor : .primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                } else {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.05 : 0.02), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView()
}

// MARK: - AppIconView Utility
struct AppIconView: View {
    var body: some View {
        if let iconImage = getAppIcon() {
            Image(uiImage: iconImage)
                .resizable()
                .scaledToFit()
        } else {
            // Fallback if icon cannot be loaded
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.accentColor.opacity(0.2))
                .overlay(
                    Image(systemName: "bird")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                )
        }
    }
    
    private func getAppIcon() -> UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
}
