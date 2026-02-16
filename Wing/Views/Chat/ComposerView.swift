//
//  ComposerView.swift
//  Wing
//
//  Created on 2026-02-16.
//

import SwiftUI
import PhotosUI
import SwiftData

/**
 * 半屏输入视图（"当下" Sheet）
 *
 * 基于 ShipSwift `component-add-sheet` 的设计模式，
 * 为 Wing 定制的碎片记录输入界面：
 * - 大文本框（自适应高度）
 * - 图片选择（PhotosPicker）
 * - 发送后保持 Sheet，支持连续输入
 */
struct ComposerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NavigationManager.self) private var navManager
    
    @State private var inputText = ""
    @State private var sessionService = SessionService()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isProcessingImage = false
    @State private var voiceInputManager = VoiceInputManager()
    @State private var savedInputText = ""
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        @Bindable var nav = navManager
        

        
        NavigationStack {
            VStack(spacing: 0) {
                // 输入区域
                inputArea
                
                Spacer()
                
                // 底部工具栏
                bottomToolbar
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            // 监听语音输入
            .onChange(of: voiceInputManager.recognizedText) { _, newText in
                inputText = savedInputText + newText
            }
            .onChange(of: voiceInputManager.isRecording) { _, isRecording in
                if isRecording {
                    savedInputText = inputText
                }
            }
            // 错误提示
            .alert(L("voice.input.permission.denied"), isPresented: .constant(voiceInputManager.error != nil)) {
                Button(L("common.ok")) {
                    voiceInputManager.error = nil // Clear error
                }
            } message: {
                if let error = voiceInputManager.error {
                     Text(error)
                }
            }
        }
        .presentationDetents(
            [.fraction(0.25), .medium, .large],
            selection: $nav.composerDetent
        )
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationDragIndicator(.visible)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        TextField(L("composer.placeholder"), text: $inputText, axis: .vertical)
            .lineLimit(1...15) // Allow growth but start small
            .focused($isFocused)
            .padding(.horizontal, 20)
            .padding(.top, 48)
            .padding(.bottom, 8)
    }
    
    // MARK: - Bottom Toolbar
    
    // MARK: - Bottom Toolbar
    
    private var bottomToolbar: some View {
        HStack(alignment: .bottom, spacing: 20) { // Increased spacing for cleaner look
            // 图片选择
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images
            ) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title3)
            }
            .tint(.secondary) // Force gray tint
            .disabled(isProcessingImage)
            .onChange(of: selectedPhoto) { _, newValue in
                handlePhotoSelection(newValue)
            }
            
            // 日期时间选择
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showDatePicker.toggle()
                    }
                } label: {
                    Image(systemName: "clock")
                        .font(.title3)
                        .foregroundStyle(showDatePicker || !Calendar.current.isDateInToday(selectedDate) ? Color.accentColor : Color.secondary)
                }
                
                if showDatePicker {
                    DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .scaleEffect(0.85)
                        .transition(.scale.combined(with: .opacity).animation(.snappy))
                }
            }
            
            Spacer()
            
            // 发送/语音按钮
            let isRecording = voiceInputManager.isRecording
            let hasText = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            if !hasText && !isRecording {
                Button {
                    handleVoiceInput()
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.title3) // Consistent size
                        .padding(4)
                }
                .tint(.secondary) // Force gray tint
            } else {
                Button {
                    if isRecording {
                        voiceInputManager.stopRecording()
                    } else {
                        handleSendText()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } label: {
                    Image(systemName: isRecording ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .symbolEffect(.pulse, isActive: isRecording)
                        .foregroundStyle(isRecording ? .red : .accentColor)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .padding(.top, 8)
        .background(AnyShapeStyle(Color.clear)) // Clean look matching compact mode
    }
    
    // MARK: - Actions
    
    private func handleSendText() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // 捕获当前状态供异步使用
        let capturedText = text
        let capturedDate = selectedDate
        
        Task {
            let dateStr = formatDate(capturedDate)
            let session = sessionService.getOrCreateSession(
                for: dateStr,
                context: modelContext
            )
            
            sessionService.addTextFragment(
                capturedText,
                date: capturedDate,
                to: session,
                context: modelContext
            )
        }
        
        // 清空输入，保持 Sheet 不关闭（连续输入）
        inputText = ""
    }
    
    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        // 1. 立即关闭 UI（Optimistic UI）
        dismiss()
        selectedPhoto = nil // 重置选中状态
        
        // 捕获必要的上下文信息（主线程）
        let container = modelContext.container
        let mainContext = modelContext
        let mainSessionService = sessionService
        let capturedDate = selectedDate
        
        // 2. 启动后台任务处理图片
        Task.detached(priority: .userInitiated) {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    // 创建后台 Actor 和 Context
                    let bgContext = ModelContext(container)
                    let service = SessionService()
                    
                    // 日期格式化（后台线程）
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    formatter.timeZone = TimeZone.current
                    let dateStr = formatter.string(from: capturedDate)
                    
                    // 获取 Session
                    let session = service.getOrCreateSession(
                        for: dateStr,
                        context: bgContext
                    )
                    
                    // 3. 添加"处理中"的占位记录（立即显示模糊图）
                    let id = service.addPendingImageFragment(
                        data,
                        date: capturedDate,
                        to: session,
                        context: bgContext
                    )
                    
                    // 4. 执行压缩（耗时操作）
                    let compressor = ImageCompressor()
                    // 模拟压缩耗时以展示效果（生产环境可移除）
                    try? await Task.sleep(for: .milliseconds(500))
                    
                    if let compressedData = await compressor.compress(data) {
                        // 5. 完成处理（切换回主线程更新以触发 UI 刷新）
                        await MainActor.run {
                             mainSessionService.completeImageFragment(
                                id: id,
                                finalData: compressedData,
                                context: mainContext
                            )
                        }
                    }
                }
            } catch {
                print("后台图片处理失败: \(error)")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    private func handleVoiceInput() {
        if !voiceInputManager.permissionGranted {
             voiceInputManager.checkPermissions()
        } else {
             voiceInputManager.startRecording()
             UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}

#Preview {
    ComposerView()
        .modelContainer(for: [
            DailySession.self,
            RawFragment.self
        ], inMemory: true)
}
