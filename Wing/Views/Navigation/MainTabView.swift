//
//  MainTabView.swift
//  Wing
//
//  Created on 2026-01-29.
//

import SwiftUI
import SwiftData
import UIKit

/**
 * 主 Tab 视图
 *
 * Wing 应用的主导航容器，包含三个核心 Tab：
 * - 当下（Now）：聊天/记录界面
 * - 回忆（Journal）：日记列表与详情
 * - 设置（Settings）：应用配置
 */
struct MainTabView: View {
    @State private var navigationManager = NavigationManager()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Content Layer
                Group {
                    switch navigationManager.selectedTab {
                    case .now:
                        ChatView()
                    case .journal:
                        JournalTabView()
                    case .settings:
                        SettingsTabView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Overlay Layer (Custom Tab Bar)
                VStack {
                    Spacer()
                    if navigationManager.shouldShowTabBar {
                        CustomTabBar(
                            selectedTab: $navigationManager.selectedTab,
                            onCompose: {
                                navigationManager.showComposer = true
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .ignoresSafeArea(.keyboard) // 防止键盘顶起 TabBar
            }
            // 移除原生 TabBar 相关修饰符
            .sheet(isPresented: $navigationManager.showComposer) {
                ComposerView()
                    .presentationBackground(.ultraThinMaterial)
            }
            .environment(navigationManager)
            .environment(SettingsManager.shared)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .overlay {
                if navigationManager.isSynthesizing {
                    let fallbackTarget = CGRect(
                        x: 24 + 4 + 26, // Horizontal Padding 24 + Capsule Padding 4 + Half Button Width 26
                        y: geometry.size.height - 16 - 25, // Bottom Padding 16 + Half Capsule Height 25
                        width: 10, height: 10
                    )
                    
                    ParticleEffectView(
                        isActive: navigationManager.isSynthesizing,
                        sourceRects: navigationManager.bubbleAnchors,
                        targetRect: navigationManager.journalIconAnchor == .zero ? fallbackTarget : navigationManager.journalIconAnchor,
                        geometry: geometry
                    )
                    .allowsHitTesting(false)
                    .onAppear {
                        if navigationManager.isSynthesizing {
                            // spawn handled by view
                        }
                    }
                }
            }
            .overlayPreferenceValue(JournalIconAnchorKey.self) { anchor in
                if let anchor = anchor {
                    let rect = geometry[anchor]
                    Color.clear
                        .task(id: rect) {
                            navigationManager.journalIconAnchor = rect
                        }
                }
            }
            .onPreferenceChange(BubbleAnchorKey.self) { anchors in
                navigationManager.bubbleAnchors = anchors
            }
        }
    }
}

// MARK: - Custom Tab Bar

private struct CustomTabBar: View {
    @Environment(NavigationManager.self) private var navigationManager
    @Binding var selectedTab: AppTab
    let onCompose: () -> Void
    
    // Long Press State
    @State private var pressTimer: Timer?
    @State private var ignoreNextTap = false // Flag to prevent tap after synthesis
    @Environment(\.modelContext) private var modelContext
    @Query private var allSessions: [DailySession] // To check if we can synthesize
    
    // Animation Namespace for Sliding Effect
    @Namespace private var animation
    @Namespace private var glassNamespace
    
    var body: some View {
        GlassEffectContainer {
        HStack(alignment: .bottom, spacing: 0) {
            // Left Capsule Group: Journal | Settings
            HStack(spacing: 0) {
                // Journal Tab
                Button {
                    if selectedTab != .journal {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = .journal
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } label: {
                    VStack(spacing: 0) {
                        Image(systemName: selectedTab == .journal ? "book.pages.fill" : "book.pages")
                            .font(.system(size: 20))
                            // Journal Pulse Effect during Synthesis
                            .symbolEffect(.bounce, options: .repeating, isActive: navigationManager.isSynthesizing)
                    }
                    // Highlight color if selected OR synthesizing
                    .foregroundStyle(selectedTab == .journal || navigationManager.isSynthesizing ? Color.accentColor : Color.secondary)
                    .frame(width: 52, height: 44)
                    .background {
                        if selectedTab == .journal {
                            Capsule()
                                .fill(Color.accentColor.opacity(0.15))
                                .matchedGeometryEffect(id: "selection", in: animation)
                        }
                    }
                }
                .disabled(navigationManager.isSynthesizing)
                .glassEffectID("tab-journal", in: glassNamespace)
                // Report Anchor for Journal Icon
                .anchorPreference(key: JournalIconAnchorKey.self, value: .bounds) { anchor in
                    return anchor
                }

                // Settings Tab
                Button {
                    if selectedTab != .settings {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = .settings
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } label: {
                    VStack(spacing: 0) {
                        Image(systemName: selectedTab == .settings ? "gearshape.fill" : "gearshape")
                            .font(.system(size: 20))
                    }
                    .foregroundStyle(selectedTab == .settings ? Color.accentColor : Color.secondary)
                    .frame(width: 52, height: 44)
                    .background {
                        if selectedTab == .settings {
                            Capsule()
                                .fill(Color.accentColor.opacity(0.15))
                                .matchedGeometryEffect(id: "selection", in: animation)
                        }
                    }
                .glassEffectID("tab-settings", in: glassNamespace)
                }
            }
            .padding(.horizontal, 4)
            .frame(height: 50)
            .glassEffect(.regular, in: Capsule())
            
            Spacer()
            
            // Right Action Button
            ZStack {
                // Progress Ring
                if navigationManager.chargingProgress > 0 {
                    Circle()
                        .trim(from: 0, to: navigationManager.chargingProgress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 46, height: 46)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.05), value: navigationManager.chargingProgress)
                }
                
                Button {
                     // Interaction Fix: Ignore tap if synthesis was just triggered
                     if ignoreNextTap {
                         ignoreNextTap = false
                         return
                     }
                    
                    // Tap action handled by SimultaneousGesture logic below?
                    // Actually, Button action is the primary tap handler.
                    if selectedTab == .now {
                        onCompose()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = .now
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } label: {
                    ZStack {
                        // 图标区域（不再需要单独的 Circle 背景）

                        if navigationManager.isSynthesizing {
                             if case .completed = navigationManager.synthesisProgress {
                                 // Completed State - Checkmark
                                 Image(systemName: "checkmark")
                                     .font(.system(size: 24, weight: .bold))
                                     .foregroundStyle(Color.accentColor)
                                     .transition(.scale.combined(with: .opacity))
                             } else {
                                 // Generating State - Infinity + Ring
                                 ZStack {
                                     // Track
                                     Circle()
                                         .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                                         .frame(width: 46, height: 46)
                                     
                                     // Progress Ring
                                     Circle()
                                         .trim(from: 0, to: navigationManager.synthesisProgressValue)
                                         .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                         .frame(width: 46, height: 46)
                                         .rotationEffect(.degrees(-90))
                                         .animation(.spring(response: 0.5, dampingFraction: 0.7), value: navigationManager.synthesisProgressValue)
                                     
                                     // Center Icon
                                     Image(systemName: "infinity")
                                         .font(.system(size: 20, weight: .semibold))
                                         .foregroundStyle(Color.accentColor)
                                 }
                                 .transition(.scale.combined(with: .opacity))
                             }
                        } else {
                            // Icon Switch Logic
                            Image(systemName: selectedTab == .now ? "square.and.pencil" : "text.bubble.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .frame(width: 50, height: 50)
                    .glassEffect(.regular, in: .circle)
                    .scaleEffect(navigationManager.isCharging ? 1.1 : 1.0)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if selectedTab == .now && !navigationManager.isCharging {
                                startLongPress()
                            }
                        }
                        .onEnded { _ in
                            handleGestureEnd()
                        }
                )
            }
            .glassEffectID("tab-now", in: glassNamespace)
        }
        } // GlassEffectContainer
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - Long Press & Gesture Logic
    
    private func startLongPress() {
        guard let todaySession = currentSession, !todaySession.fragments.isEmpty else { 
            // 如果没有今天的碎片，直接触发 tap 效果（或者不做任何事，取决于是否允许空 session 合成）
            // 这里假设没碎片不能合成，所以不开始蓄力
            return 
        }
        guard !navigationManager.isSynthesizing else { return }
        
        // Reset state
        ignoreNextTap = false
        
        // 开始蓄力
        navigationManager.chargingProgress = 0.01 // Start slightly above 0 to trigger UI
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Start Timer for progress (1.0 second duration)
        let startTime = Date()
        pressTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / 1.0, 1.0)
            let isComplete = progress >= 1.0
            
            if isComplete {
                timer.invalidate()
            }
            
            Task { @MainActor in
                navigationManager.chargingProgress = progress
                
                if isComplete {
                    triggerSynthesis()
                } else {
                     // Haptic feedback increases with progress
                     if Int(progress * 100) % 20 == 0 {
                         UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: progress)
                     }
                }
            }
        }
    }
    
    private func handleGestureEnd() {
        pressTimer?.invalidate()
        pressTimer = nil
        
        if navigationManager.chargingProgress >= 1.0 {
            // Already triggered synthesis, do nothing. 
            // user released button, ignoreNextTap is already set to true in triggerSynthesis
        } else if navigationManager.chargingProgress > 0.1 {
            // Cancelled charging
            withAnimation(.easeOut(duration: 0.2)) {
                navigationManager.chargingProgress = 0.0
            }
        } else {
            // Tap detected (short press) - handled by Button action?
            // DragGesture onEnded fires before or after Button action?
            // If we reset progress here, it just hides the UI.
            withAnimation(.easeOut(duration: 0.2)) {
                navigationManager.chargingProgress = 0.0
            }
        }
    }
    
    private func triggerSynthesis() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        
        // Set ignore flag to prevent button tap action
        ignoreNextTap = true
        
        // Reset charging progress but keep synthesizing state
        withAnimation {
             navigationManager.chargingProgress = 0.0
        }
        
        guard let session = currentSession else { return }
        
        Task {
            await MainActor.run {
                navigationManager.isSynthesizing = true
                navigationManager.synthesisProgress = .started
            }
            
            do {
                guard let config = await SettingsManager.shared.getAIConfig() else {
                    throw SynthesisError.configurationMissing
                }
                
                let journalLanguage = SettingsManager.shared.appSettings?.journalLanguage ?? .auto
                
                let entryId = try await JournalSynthesisService.shared.synthesize(
                    session: session,
                    config: config,
                    journalLanguage: journalLanguage,
                    context: modelContext,
                    progressCallback: { progress in
                        Task { @MainActor in
                            navigationManager.synthesisProgress = progress
                        }
                    }
                )
                
                try await Task.sleep(for: .seconds(1))
                
                await MainActor.run {
                    navigationManager.isSynthesizing = false
                    navigationManager.navigateToJournalDetail(entryId: entryId)
                }
                
            } catch {
                await MainActor.run {
                    navigationManager.isSynthesizing = false
                    print("Synthesis failed: \(error)")
                }
            }
        }
    }
    
    private var currentSession: DailySession? {
        return allSessions.first { $0.date == navigationManager.selectedDate }
    }
}

// MARK: - Helper Views
// GlassHighlight / GlassCircleHighlight 已由 iOS 26 原生 .glassEffect() 替代

struct ProgressIcon: View {
    let progress: SynthesisProgress
    
    var body: some View {
        Group {
            switch progress {
            case .started:
                ProgressView()
                    .controlSize(.mini)
            case .generating:
                Image(systemName: "wand.and.stars")
                    .symbolEffect(.wiggle)
            case .saving:
                Image(systemName: "brain.head.profile")
                    .symbolEffect(.pulse)
            case .completed:
                Image(systemName: "checkmark")
            case .failed:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }
        .font(.system(size: 20))
    }
}

struct TabBarButton: View {
    let tab: AppTab
    let icon: String
    var selectedIcon: String? = nil
    let title: String
    @Binding var selectedTab: AppTab
    
    var body: some View {
        Button {
            if selectedTab != tab {
                selectedTab = tab
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: selectedTab == tab ? (selectedIcon ?? icon + ".fill") : icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
            .frame(width: 60, height: 44)
        }
    }
}

// MARK: - Tab Content Views

/**
 * 回忆 Tab 视图
 *
 * 包含 NavigationStack 以支持推入日记详情页
 */
private struct JournalTabView: View {
    @Environment(NavigationManager.self) private var navigationManager
    @Query(sort: \WingEntry.createdAt, order: .reverse) private var entries: [WingEntry]
    
    var body: some View {
        @Bindable var navManager = navigationManager
        
        NavigationStack(path: $navManager.journalPath) {
            Group {
                if entries.isEmpty {
                    EmptyStateView(
                        systemImage: "book.closed",
                        title: L("journal.empty"),
                        description: L("journal.empty.hint")
                    )
                    .background(Color(uiColor: .systemBackground))
                } else {
                    List {
                        ForEach(entries) { entry in
                            NavigationLink(value: AppRoute.journalDetail(entryId: entry.id)) {
                                HStack {
                                    Text(entry.mood)
                                        .font(.title2)
                                    Text(entry.title)
                                        .font(.headline)
                                    Spacer()
                                    // 右侧日期（优先使用 session.date，fallback 到 createdAt）
                                    Text(formatEntryDate(entry))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .contentMargins(.bottom, 80, for: .scrollContent)
                }
            }
            .navigationTitle(L("journal.title"))
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .journalDetail(let entryId):
                    JournalDetailView(entryId: entryId)
                default:
                    Text(L("journal.unknown.route"))
                }
            }
        }
    }
    
    /// 格式化日记日期 (MM/dd)
    private func formatEntryDate(_ entry: WingEntry) -> String {
        // 始终优先显示 entry.createdAt
        let date = Date(timeIntervalSince1970: TimeInterval(entry.createdAt) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    /// 格式化日期字符串 (MM/dd)
    private func formatListDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

/**
 * 设置 Tab 视图
 *
 * 复用现有的 SettingsEntryView
 */
private struct SettingsTabView: View {
    var body: some View {
        NavigationStack {
            SettingsEntryView()
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [
            DailySession.self,
            WingEntry.self,
            RawFragment.self,
            SemanticMemory.self,
            EpisodicMemory.self,
            ProceduralMemory.self,
            AppSettings.self
        ], inMemory: true)
}
