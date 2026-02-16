//
//  FragmentBubble.swift
//  Wing
//
//  Created on 2026-01-29.
//

import SwiftUI
import SwiftData

/**
 * 碎片气泡组件
 *
 * 支持两种类型：
 * - text: 显示文本内容
 * - image: 异步加载并显示图片
 */
struct FragmentBubble: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationManager.self) private var navigationManager
    
    let fragment: RawFragment
    let showTimestamp: Bool
    var onImageTap: ((UIImage) -> Void)? = nil
    
    @State private var showEditSheet = false
    @State private var editedContent = ""
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // 气泡内容
            HStack {
                Spacer(minLength: 60) // 左侧留白
                
                bubbleContent
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
                    // 上下文菜单
                    .contextMenu {
                        if fragment.type == .text {
                            Button {
                                editedContent = fragment.content
                                showEditSheet = true
                            } label: {
                                Label(L("menu.edit"), systemImage: "pencil")
                            }
                        }
                        
                        Button(role: .destructive) {
                            deleteFragment()
                        } label: {
                            Label(L("menu.delete"), systemImage: "trash")
                        }
                    }
                    .sheet(isPresented: $showEditSheet) {
                        NavigationStack {
                            TextEditor(text: $editedContent)
                                .padding()
                                .navigationTitle(L("menu.edit"))
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button(L("menu.cancel")) { showEditSheet = false }
                                    }
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button(L("menu.save")) {
                                            saveEdit()
                                            showEditSheet = false
                                        }
                                        .disabled(editedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    }
                                }
                        }
                        .presentationDetents([.medium])
                    }
                    // Charging Glow Effect
                    .overlay {
                        if navigationManager.chargingProgress > 0 {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.accentColor, lineWidth: 2)
                                .opacity(navigationManager.chargingProgress)
                                .blur(radius: 2)
                                .padding(-2)
                        }
                    }
                    // Report Frame for Particles
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: BubbleAnchorKey.self,
                                value: [geo.frame(in: .global)]
                            )
                        }
                    )
            }
            
            // 时间戳（条件显示）
            if showTimestamp {
                timestampLabel
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
    
    // MARK: - Bubble Content
    
    @ViewBuilder
    private var bubbleContent: some View {
        switch fragment.type {
        case .text:
            Text(fragment.content)
                .font(.body)
                .textSelection(.enabled)
        
        case .image:
            if let imageData = fragment.imageData,
               let uiImage = UIImage(data: imageData) {
                ZStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 250)
                            .cornerRadius(8)
                            // 处理状态下的视觉效果
                            .blur(radius: fragment.isProcessing ? 15 : 0)
                            .animation(.easeOut(duration: 0.5), value: fragment.isProcessing)
                            .onTapGesture {
                                if !fragment.isProcessing {
                                    onImageTap?(uiImage)
                                }
                            }
                        
                        if !fragment.content.isEmpty {
                            Text(fragment.content)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // 加载中指示器
                    if fragment.isProcessing {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                            .background {
                                Circle()
                                    .fill(.black.opacity(0.3))
                                    .frame(width: 50, height: 50)
                            }
                            .transition(.opacity.animation(.easeInOut))
                    }
                }
            } else {
                // 图片加载失败占位
                HStack {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                    Text(L("chat.image.failed"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 200, height: 150)
            }
        }
    }
    
    // MARK: - Timestamp Label
    
    private var timestampLabel: some View {
        let timestamp = fragment.editedAt ?? fragment.timestamp
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let timeString = formatTime(date)
        
        return Group {
            if fragment.editedAt != nil {
                Text(String(format: L("chat.edited"), timeString))
            } else {
                Text(timeString)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func deleteFragment() {
        modelContext.delete(fragment)
        try? modelContext.save()
    }
    
    private func saveEdit() {
        fragment.content = editedContent
        fragment.editedAt = Int64(Date().timeIntervalSince1970 * 1000)
    }
}

#Preview {
    VStack(spacing: 16) {
        FragmentBubble(
            fragment: RawFragment(
                content: "这是一条测试消息",
                timestamp: Int64(Date().timeIntervalSince1970 * 1000),
                type: .text
            ),
            showTimestamp: true
        )
        
        FragmentBubble(
            fragment: RawFragment(
                content: "这是另一条消息",
                timestamp: Int64(Date().timeIntervalSince1970 * 1000),
                type: .text
            ),
            showTimestamp: false
        )
    }
    .environment(NavigationManager())
}
