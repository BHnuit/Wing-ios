//
//  JournalDetailView.swift
//  Wing
//
//  Created on 2026-01-29.
//

import SwiftUI
import SwiftData

/**
 * 日记详情视图
 *
 * 布局：
 * 1. Cover: 封面图片（可点击放大）
 * 2. Header: 标题 + 日期 + 摘要
 * 3. Content: 正文
 * 4. Insight: 猫头鹰的洞察
 */
struct JournalDetailView: View {
    let entryId: UUID
    @Query private var entries: [WingEntry]
    
    // 图片放大状态
    @State private var selectedImage: UIImage?
    @State private var showImageViewer = false
    
    private var entry: WingEntry? {
        entries.first { $0.id == entryId }
    }
    
    var body: some View {
        Group {
            if let entry = entry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Cover: 封面图片
                        if !entry.images.isEmpty {
                            coverSection(entry)
                        }
                        
                        // Header: 标题 + 日期 + 摘要
                        headerSection(entry)
                            .padding(.horizontal)
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Content: 正文（Markdown 渲染）
                        MarkdownContentView(markdown: entry.markdownContent)
                            .padding(.horizontal)
                        
                        // Insight: 猫头鹰的洞察
                        if !entry.aiInsights.isEmpty {
                            Divider()
                                .padding(.horizontal)
                            insightSection(entry)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.bottom)
                }
            } else {
                ContentUnavailableView(
                    "日记不存在",
                    systemImage: "exclamationmark.triangle",
                    description: Text("无法找到该日记")
                )
            }
        }
        .navigationTitle("日记详情")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImageViewer) {
            if let image = selectedImage {
                ImageViewerView(image: image) {
                    showImageViewer = false
                }
            }
        }
    }
    
    // MARK: - Cover Section
    
    @ViewBuilder
    private func coverSection(_ entry: WingEntry) -> some View {
        let imageDataArray = Array(entry.images.values)
        
        if imageDataArray.count == 1 {
            // 单张图片：全宽封面
            if let imageData = imageDataArray.first, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 220)
                    .clipped()
                    .onTapGesture {
                        selectedImage = uiImage
                        showImageViewer = true
                    }
            }
        } else {
            // 多张图片：横向滚动
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(imageDataArray, id: \.self) { imageData in
                        if let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 180, height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onTapGesture {
                                    selectedImage = uiImage
                                    showImageViewer = true
                                }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 180)
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private func headerSection(_ entry: WingEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            Text(entry.title)
                .font(.title)
                .fontWeight(.bold)
            
            // 日期
            if let date = entry.dailySession?.date {
                Text(formatDate(date))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                // Fallback: 使用 createdAt 时间戳
                Text(formatTimestamp(entry.createdAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            // 摘要
            Text(entry.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Insight Section
    
    @ViewBuilder
    private func insightSection(_ entry: WingEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("猫头鹰的洞察", systemImage: "brain.head.profile")
                .font(.headline)
                .foregroundStyle(.blue)
            
            Text(entry.aiInsights)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.blue.opacity(0.1))
                )
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        formatter.dateFormat = "yyyy年MM月dd日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - Image Viewer

/**
 * 图片查看器（使用 sheet 而非 fullScreenCover 以避免白屏问题）
 */
struct ImageViewerView: View {
    let image: UIImage
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @GestureState private var magnifyBy: CGFloat = 1.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale * magnifyBy)
                    .gesture(
                        MagnifyGesture()
                            .updating($magnifyBy) { value, state, _ in
                                state = value.magnification
                            }
                            .onEnded { value in
                                scale *= value.magnification
                                // 限制缩放范围
                                scale = min(max(scale, 1.0), 4.0)
                            }
                    )
                    .onTapGesture(count: 2) {
                        // 双击恢复原始大小
                        withAnimation {
                            scale = 1.0
                        }
                    }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    NavigationStack {
        JournalDetailView(entryId: UUID())
            .modelContainer(for: [
                WingEntry.self,
                DailySession.self
            ], inMemory: true)
    }
}
