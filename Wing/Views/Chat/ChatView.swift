//
//  ChatView.swift
//  Wing
//
//  Created on 2026-01-29.
//

import SwiftUI
import SwiftData

/**
 * 聊天记录主视图
 *
 * 功能：
 * - 显示当天的碎片记录
 * - 支持日期切换查看历史
 * - 发送文本和图片消息
 * - 自动滚动到底部
 */
struct ImagePreviewItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationManager.self) private var navigationManager
    @Environment(SettingsManager.self) private var settingsManager
    @Query private var allSessions: [DailySession]
    
    @State private var sessionService = SessionService()
    @State private var selectedImageItem: ImagePreviewItem?
    
    // 日记合成状态
    @State private var synthesisError: Error?
    
    // 当前查看的 Session
    private var currentSession: DailySession? {
        allSessions.first { $0.date == navigationManager.selectedDate }
    }
    
    // 碎片列表（按时间排序）
    private var fragments: [RawFragment] {
        currentSession?.fragments.sorted { $0.timestamp < $1.timestamp } ?? []
    }
    
    // 有记录的日期列表 (始终包含今天，确保可导航)
    private var availableDates: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        
        var dates = Set(allSessions.map { $0.date })
        dates.insert(today)
        return Array(dates).sorted()
    }
    
    init() {
        // init body does not need to manage state anymore
    }
    
    var body: some View {
        @Bindable var navigationManager = navigationManager
        NavigationStack {
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    // 背景与内容
                    ZStack {
                        // 背景
                        Color(uiColor: .systemGroupedBackground)
                            .ignoresSafeArea()
                        
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    // 顶部留白，避免被悬浮导航栏遮挡
                                    Color.clear.frame(height: 60)
                                    
                                    if fragments.isEmpty {
                                        emptyStateView
                                    } else {
                                        ForEach(Array(fragments.enumerated()), id: \.element.id) { index, fragment in
                                            let nextFragment = index < fragments.count - 1 ? fragments[index + 1] : nil
                                            let showTimestamp = shouldShowTimestamp(
                                                current: fragment,
                                                next: nextFragment
                                            )
                                            
                                            // 相同时间段内的气泡间距减半 (6pt)，否则保持标准间距 (12pt)
                                            let bottomSpacing: CGFloat = showTimestamp ? 12 : 6
                                            
                                            FragmentBubble(
                                                fragment: fragment,
                                                showTimestamp: showTimestamp,
                                                onImageTap: { image in
                                                    selectedImageItem = ImagePreviewItem(image: image)
                                                }
                                            )
                                            .id(fragment.id)
                                            .padding(.bottom, bottomSpacing)
                                        }
                                    }
                                }
                                .padding(.top, 8)
                                .padding(.bottom, bottomPadding(in: geometry)) // Dynamic padding for composer
                                
                                // 底部锚点
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom")
                            }
                            .scrollDismissesKeyboard(.interactively)
                            .onChange(of: fragments.count) { _, _ in
                                scrollToBottom(proxy: proxy)
                            }
                            // 监听 Composer 状态变化，调整滚动
                            .onChange(of: navigationManager.showComposer) { _, shown in
                                if shown {
                                    // 延迟一点滚动，等待键盘或 Sheet 动画
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        scrollToBottom(proxy: proxy)
                                    }
                                }
                            }
                            .onChange(of: navigationManager.composerDetent) { _, _ in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    scrollToBottom(proxy: proxy)
                                }
                            }
                        }
                    }
                    .alert(L("chat.generate.failed"), isPresented: .constant(synthesisError != nil)) {
                        Button(L("chat.ok")) {
                            synthesisError = nil
                        }
                    } message: {
                        if let error = synthesisError {
                            Text(error.localizedDescription)
                        }
                    }
                    
                    // 顶部渐变遮罩 (使气泡滚动到顶部时自然淡出)
                    LinearGradient(
                        stops: [
                            .init(color: Color(uiColor: .systemGroupedBackground), location: 0.0),
                            .init(color: Color(uiColor: .systemGroupedBackground).opacity(0.8), location: 0.6),
                            .init(color: Color(uiColor: .systemGroupedBackground).opacity(0.0), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 140)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                    
                    // 顶部悬浮日期导航 (无背景容器)
                    DateNavigator(
                        selectedDate: $navigationManager.selectedDate,
                        availableDates: availableDates
                    )
                    .padding(.top, 0) // Align to safe area top
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(item: $selectedImageItem) { item in
                FullScreenImageViewer(image: item.image) {
                    selectedImageItem = nil
                }
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        // 仅今日且无记录时显示极简引导，过去日期无记录则保持空白（不可达）
        Group {
            if isToday {
                EmptyStateView(
                    systemImage: "square.and.pencil",
                    title: nil,
                    description: L("chat.empty.today")
                )
                .padding(.top, 100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var isToday: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return navigationManager.selectedDate == formatter.string(from: Date())
    }
    
    // MARK: - Actions
    
    // MARK: - Helper Methods
    
    private func bottomPadding(in geometry: GeometryProxy) -> CGFloat {
        guard navigationManager.showComposer else { return 0 }
        
        // 当 Composer 展开时，计算遮挡高度
        // .fraction(0.25) 对应 1/4 屏
        // .medium 对应 1/2 屏
        // .large 对应全屏 (虽然全屏时看不到 ChatView，但保持逻辑一致)
        
        if navigationManager.composerDetent == .fraction(0.25) {
            return geometry.size.height * 0.25 - 20 // Reduce gap further
        } else if navigationManager.composerDetent == .medium {
            return geometry.size.height * 0.5 + 40
        } else if navigationManager.composerDetent == .large {
            return geometry.size.height * 0.9
        }
        
        // Default fallback
        return 0
    }
    
    /**
     * 判断是否显示时间戳（5分钟内合并）
     */
    private func shouldShowTimestamp(current: RawFragment, next: RawFragment?) -> Bool {
        guard let next = next else { return true }
        let diff = next.timestamp - current.timestamp
        return diff > 5 * 60 * 1000 // 5 分钟（毫秒）
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DailySession.self, RawFragment.self, WingEntry.self, configurations: config)
    let navManager: NavigationManager = {
        let manager = NavigationManager()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // Set to today to show empty state
        manager.selectedDate = formatter.string(from: Date())
        return manager
    }()
    
    return ChatView()
        .environment(navManager)
        .environment(SettingsManager.shared)
        .modelContainer(container)
}
