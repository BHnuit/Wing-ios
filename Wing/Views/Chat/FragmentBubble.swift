//
//  FragmentBubble.swift
//  Wing
//
//  Created on 2026-01-29.
//

import SwiftUI

/**
 * 碎片气泡组件
 *
 * 支持两种类型：
 * - text: 显示文本内容
 * - image: 异步加载并显示图片
 */
struct FragmentBubble: View {
    let fragment: RawFragment
    let showTimestamp: Bool
    
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
                VStack(alignment: .leading, spacing: 4) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 250)
                        .cornerRadius(8)
                    
                    if !fragment.content.isEmpty {
                        Text(fragment.content)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                // 图片加载失败占位
                HStack {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                    Text("图片加载失败")
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
                Text("已编辑 \(timeString)")
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
}
