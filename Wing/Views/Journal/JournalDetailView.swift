//
//  JournalDetailView.swift
//  Wing
//
//  Created on 2026-01-29.
//

import SwiftUI
import SwiftData
import PhotosUI

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
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationManager.self) private var navigationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    
    let entryId: UUID
    @Query private var entries: [WingEntry]
    
    // 编辑状态
    @State private var isEditing = false
    @State private var editedTitle = ""
    @State private var editedContent = ""
    @FocusState private var isContentFocused: Bool
    
    // 确认对话框
    @State private var showDeleteConfirmation = false
    
    // 图片放大状态
    struct JournalImageViewerItem: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    @State private var selectedImageItem: JournalImageViewerItem?
    
    // 导出状态
    @State private var exportItem: ExportItem?
    
    // Expanded Edit State
    @State private var editedDate: Date = Date()
    @State private var editedSummary: String = ""
    
    // Image Management State
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var replacingImageId: UUID?
    @State private var showPhotoPicker = false // If set, we are replacing this image. If nil and picker active, maybe adding? (Current requirement only mentions replace/delete)
    
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
                        
                        // Content: 正文（Markdown 渲染 或 编辑器）
                        if isEditing {
                            TextEditor(text: $editedContent)
                                .font(.body)
                                .frame(minHeight: 400)
                                .focused($isContentFocused)
                                .scrollContentBackground(.hidden)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        } else {
                            MarkdownContentView(markdown: entry.markdownContent)
                                .padding(.horizontal)
                        }
                        
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
                    L("journal.detail.notFound"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(L("journal.detail.notFound.desc"))
                )
            }
        }
        .navigationTitle(isEditing ? L("journal.detail.editing") : L("journal.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isEditing {
                    Button(L("common.done")) {
                        saveChanges()
                    }
                    .fontWeight(.bold)
                } else {
                    Menu {
                        Button {
                            startEditing()
                        } label: {
                            Label(L("journal.action.edit"), systemImage: "pencil")
                        }
                        
                        Button {
                            duplicateEntry()
                        } label: {
                            Label(L("journal.action.duplicate"), systemImage: "plus.square.on.square")
                        }
                        
                        Button {
                            copyContent()
                        } label: {
                            Label(L("journal.action.copy"), systemImage: "doc.on.doc")
                        }
                        
                        Button {
                            Task {
                                await exportEntry()
                            }
                        } label: {
                            Label(L("journal.action.exportImage"), systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            jumpToChat()
                        } label: {
                            Label(L("journal.action.jumpToChat"), systemImage: "message")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label(L("journal.action.delete"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) {
                        cancelEditing()
                    }
                }
            }
        }
        .alert(L("journal.delete.confirm"), isPresented: $showDeleteConfirmation) {
            Button(L("menu.delete"), role: .destructive) { // Corrected from common.delete/commond.delete to menu.delete or just ensure key exists
                deleteEntry()
            }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("journal.delete.message"))
        }
        .fullScreenCover(item: $selectedImageItem) { item in
            FullScreenImageViewer(image: item.image) {
                selectedImageItem = nil
            }
        }
        .sheet(item: $exportItem) { item in
            ShareSheet(activityItems: [item.url])
                .presentationDetents([.medium, .large])
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self), let replaceId = replacingImageId {
                    if let entry = entry {
                        var currentImages = entry.images
                        currentImages[replaceId] = data
                        entry.images = currentImages
                    }
                    // Reset
                    replacingImageId = nil
                    selectedPhotoItem = nil
                }
            }
        }
    }
    
    // MARK: - Cover Section
    
    @ViewBuilder
    private func coverSection(_ entry: WingEntry) -> some View {
        // Sort images by UUID string to ensure consistent order
        let imageDataArray = Array(entry.images).sorted { $0.key.uuidString < $1.key.uuidString }
        
        if imageDataArray.count == 1 {
            // 单张图片：全宽封面
            if let (id, data) = imageDataArray.first, let uiImage = UIImage(data: data) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 220)
                        .clipped()
                        .contentShape(Rectangle()) // Ensure tap works
                        .onTapGesture {
                            if !isEditing { // Only allow view when not editing
                                selectedImageItem = JournalImageViewerItem(image: uiImage)
                            }
                        }
                    
                    if isEditing {
                        imageEditOverlay(for: id)
                            .padding(8)
                    }
                }
            }
        } else {
            // 多张图片：横向滚动
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(imageDataArray, id: \.key) { id, data in
                        if let uiImage = UIImage(data: data) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 180, height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if !isEditing { // Only allow view when not editing
                                            selectedImageItem = JournalImageViewerItem(image: uiImage)
                                        }
                                    }
                                
                                if isEditing {
                                    imageEditOverlay(for: id)
                                        .padding(4)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 180)
        }
    }
    
    @ViewBuilder
    private func imageEditOverlay(for id: UUID) -> some View {
        HStack(spacing: 8) {
            Button {
                replacingImageId = id
                showPhotoPicker = true
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(.black.opacity(0.6))
                    .clipShape(Circle())
            }
            // Add explicit content shape to ensure tap is caught by button, not image below
            .contentShape(Circle())
            
            Button {
                deleteImage(id: id)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(.red.opacity(0.8))
                    .clipShape(Circle())
            }
            .contentShape(Circle())
        }
    }    
    
    private func deleteImage(id: UUID) {
        guard let entry = entry else { return }
        var currentImages = entry.images
        currentImages.removeValue(forKey: id)
        entry.images = currentImages
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private func headerSection(_ entry: WingEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            if isEditing {
                TextField(L("journal.edit.titlePlaceholder"), text: $editedTitle)
                    .font(.title)
                    .fontWeight(.bold)
                    .textFieldStyle(.roundedBorder)
            } else {
                Text(entry.title)
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            // 日期
            if isEditing {
                DatePicker(
                    L("journal.edit.date"),
                    selection: $editedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
            } else {
                // Always use createdAt timestamp for consistent display after editing
                Text(formatTimestamp(entry.createdAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            // 摘要
            if isEditing {
                TextField(L("journal.edit.summaryPlaceholder"), text: $editedSummary, axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            } else {
                Text(entry.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Insight Section
    
    @ViewBuilder
    private func insightSection(_ entry: WingEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L("journal.insight.title"), systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(Color.accentColor) // Use accent color
            
            // Remove "洞察：" or "Insight:" prefix if present
            let cleanInsight = entry.aiInsights
                .replacingOccurrences(of: "洞察：", with: "")
                .replacingOccurrences(of: "Insight:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            Text(cleanInsight)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemBackground)) // Use neutral background
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
        
        formatter.dateFormat = L("date.format.full")
        // Use current app language for date formatting
        let language = SettingsManager.shared.appSettings?.language ?? .zh
        let localeId: String
        switch language {
        case .system: localeId = Locale.current.identifier
        case .zh: localeId = "zh_CN"
        case .en: localeId = "en_US"
        case .ja: localeId = "ja_JP"
        }
        formatter.locale = Locale(identifier: localeId)
        return formatter.string(from: date)
    }
    
    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = L("date.format.full")
        // Use current app language for date formatting
        let language = SettingsManager.shared.appSettings?.language ?? .zh
        let localeId: String
        switch language {
        case .system: localeId = Locale.current.identifier
        case .zh: localeId = "zh_CN"
        case .en: localeId = "en_US"
        case .ja: localeId = "ja_JP"
        }
        formatter.locale = Locale(identifier: localeId)
        return formatter.string(from: date)
    }
    
    // MARK: - Actions
    
    private func startEditing() {
        guard let entry = entry else { return }
        editedTitle = entry.title
        editedContent = entry.markdownContent
        editedSummary = entry.summary
        editedDate = Date(timeIntervalSince1970: TimeInterval(entry.createdAt) / 1000)
        
        withAnimation {
            isEditing = true
        }
    }
    
    private func saveChanges() {
        guard let entry = entry else { return }
        
        // 1. Clear focus first to prevent crash (NSInternalInconsistencyException)
        isContentFocused = false
        
        // 2. Perform save
        entry.title = editedTitle
        entry.markdownContent = editedContent
        entry.summary = editedSummary
        entry.createdAt = Int64(editedDate.timeIntervalSince1970 * 1000)
        entry.editedAt = Int64(Date().timeIntervalSince1970 * 1000)
        
        try? modelContext.save()
        
        // 3. Delay state change slightly to allow focus engine to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                self.isEditing = false
            }
        }
    }
    
    private func cancelEditing() {
        isContentFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                self.isEditing = false
            }
        }
    }
    
    private func duplicateEntry() {
        guard let entry = entry else { return }
        let suffix = NSLocalizedString("journal.copy.suffix", value: " (Copy)", comment: "Suffix for duplicated journal entry")
        let newEntry = WingEntry(
            id: UUID(),
            title: entry.title + suffix,
            summary: entry.summary,
            mood: entry.mood,
            markdownContent: entry.markdownContent,
            aiInsights: entry.aiInsights,
            createdAt: entry.createdAt, // Keep original date
            generatedAt: Int64(Date().timeIntervalSince1970 * 1000),
            images: entry.images // Copy images
        )
        modelContext.insert(newEntry)
        
        // Auto navigate to new entry
        // We need to wait for SwiftData to persist and query to update? 
        // Or just navigate. Since we are in DetailView, we might need to replace current detail or go back list then forward.
        // Simplest: Pop back, then let user navigate. Or better: Just show success feedback.
        // User request: "won't auto jump to created copy". Let's try to jump.
        // Assuming NavigationManager handles selection.
        
        // Forcing a UI update cycle
        try? modelContext.save()
        
        // Dismiss current view to go back to list, then ideally user sees the new one.
        // But user wants to JUMP to it. 
        // If we are in NavigationStack via NavigationLink(value:), we can't easily switch the top of stack without popping.
        // However, if we just want to show the content, we can use NavigationManager if it controls the path.
        // But JournalDetailView is likely pushed onto stack.
        // Let's at least dismiss to list so they see it.
        dismiss()
    }
    
    private func copyContent() {
        UIPasteboard.general.string = entry?.markdownContent
    }
    
    private func jumpToChat() {
        guard let entry = entry else { return }
        
        // 优先使用 session date，如果没有则尝试从 createdAt 反推
        var targetDateString: String? = entry.dailySession?.date
        
        if targetDateString == nil {
             let date = Date(timeIntervalSince1970: TimeInterval(entry.createdAt) / 1000)
             let formatter = DateFormatter()
             formatter.dateFormat = "yyyy-MM-dd"
             targetDateString = formatter.string(from: date)
        }
        
        if let sessionDate = targetDateString {
            // 设置 NavigationManager 并在 .now tab 显示
            navigationManager.selectedDate = sessionDate
            navigationManager.selectedTab = .now
            
            // Pop back (not strictly necessary but good UX if using Push)
            // dismiss()
        }
    }
    
    private func deleteEntry() {
        guard let entry = entry else { return }
        modelContext.delete(entry)
        try? modelContext.save() // Force save to update list view immediately
        dismiss()
    }
    
    // MARK: - Export Logic
    
    @MainActor
    private func exportEntry() async {
        guard let entry = entry else { return }
        
        let shareView = JournalShareView(entry: entry)
        let renderer = ImageRenderer(content: shareView)
        renderer.scale = displayScale
        
        if let uiImage = renderer.uiImage {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Wing_Share_\(entry.id.uuidString).png")
            if let data = uiImage.pngData() {
                try? data.write(to: tempURL)
                exportItem = ExportItem(url: tempURL)
            }
        }
    }
}

struct JournalShareView: View {
    let entry: WingEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 10) {
                Text(entry.title)
                    .font(.system(size: 32, weight: .bold)) // Use fixed size for export
                    .foregroundStyle(.black)
                
                Text(formatTimestamp(entry.createdAt))
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
            }
            
            // Content
            MarkdownContentView(markdown: entry.markdownContent)
                .foregroundStyle(.black)
                
            // Images (Moved to bottom)
            if !entry.images.isEmpty {
                ForEach(Array(entry.images).sorted { $0.key.uuidString < $1.key.uuidString }, id: \.key) { _, data in
                    if let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                    }
                }
            }
            
            // Insight
            if !entry.aiInsights.isEmpty {
                Divider()
                HStack {
                    Image(systemName: "sparkles")
                    Text(L("journal.insight.title")) // Localized
                        .fontWeight(.bold)
                }
                .foregroundStyle(Color.accentColor) // Use theme accent
                
                // Remove "洞察：" or "Insight:" prefix if present for export as well
                let cleanInsight = entry.aiInsights
                    .replacingOccurrences(of: "洞察：", with: "")
                    .replacingOccurrences(of: "Insight:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                Text(cleanInsight)
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
                    .fixedSize(horizontal: false, vertical: true) // Force Wrap
            }
            
            // Footer
            HStack {
                Spacer()
                Text("Created with Wing")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
            .padding(.top, 20)
        }
        .padding(40)
        .background(Color.white)
        .frame(width: 400) // Fixed width ensures consistent layout for image generation
    }
    
    // Helper Methods for Share View
    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = L("date.format.full")
        // Use current app language for date formatting
        let language = SettingsManager.shared.appSettings?.language ?? .zh
        let localeId: String
        switch language {
        case .system: localeId = Locale.current.identifier
        case .zh: localeId = "zh_CN"
        case .en: localeId = "en_US"
        case .ja: localeId = "ja_JP"
        }
        formatter.locale = Locale(identifier: localeId)
        return formatter.string(from: date)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WingEntry.self, DailySession.self, configurations: config)
    
    let entry = WingEntry(
        title: "Test Journal",
        summary: "This is a summary of the day.",
        mood: "😊",
        markdownContent: "Today was a good day. I wrote some code.",
        aiInsights: "Insight: You are doing great! Keep it up.",
        createdAt: Int64(Date().timeIntervalSince1970 * 1000)
    )
    container.mainContext.insert(entry)
    
    return NavigationStack {
        JournalDetailView(entryId: entry.id)
            .modelContainer(container)
            .environment(NavigationManager())
    }
}
