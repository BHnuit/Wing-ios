//
//  ChatInputBar.swift
//  Wing
//
//  Created on 2026-01-29.
//

import SwiftUI
import PhotosUI

/**
 * 聊天输入栏组件
 *
 * 功能：
 * - 自动伸缩文本框
 * - 图片选择（PhotosPicker）
 * - 发送按钮
 */
struct ChatInputBar: View {
    @Binding var text: String
    let onSend: () -> Void
    let onImageSelected: (Data) async -> Void
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isProcessingImage = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // 图片选择按钮
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images
            ) {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
            }
            .disabled(isProcessingImage)
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    await handlePhotoSelection(newValue)
                }
            }
            
            // 文本输入框
            TextField("记录此刻的想法...", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .focused($isFocused)
            
            // 发送按钮
            Button {
                onSend()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(text.isEmpty ? .gray : .blue)
            }
            .disabled(text.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
    
    // MARK: - Image Handling
    
    private func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        isProcessingImage = true
        defer { isProcessingImage = false }
        
        do {
            // 加载图片数据
            if let data = try await item.loadTransferable(type: Data.self) {
                // 压缩图片
                let compressor = ImageCompressor()
                if let compressedData = await compressor.compress(data) {
                    await onImageSelected(compressedData)
                }
            }
        } catch {
            print("图片加载失败: \(error)")
        }
        
        // 重置选择
        selectedPhoto = nil
    }
}

#Preview {
    @Previewable @State var text = ""
    
    VStack {
        Spacer()
        ChatInputBar(
            text: $text,
            onSend: {
                print("发送: \(text)")
                text = ""
            },
            onImageSelected: { data in
                print("图片大小: \(data.count) bytes")
            }
        )
    }
}
