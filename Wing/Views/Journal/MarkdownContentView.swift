//
//  MarkdownContentView.swift
//  Wing
//
//  Created on 2026-01-29.
//

import SwiftUI

/**
 * Markdown 内容渲染组件
 *
 * 使用 SwiftUI 原生 AttributedString(markdown:) 实现轻量级渲染
 * 按段落分割以保留换行
 */
struct MarkdownContentView: View {
    let markdown: String
    
    // 按空行分割段落
    private var paragraphs: [String] {
        markdown
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                renderParagraph(paragraph)
            }
        }
    }
    
    @ViewBuilder
    private func renderParagraph(_ text: String) -> some View {
        if let attributedString = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .full
            )
        ) {
            Text(attributedString)
                .textSelection(.enabled)
                .font(.body)
                .lineSpacing(6)
        } else {
            // Fallback: 直接显示原始文本
            Text(text)
                .textSelection(.enabled)
                .font(.body)
                .lineSpacing(6)
        }
    }
}

#Preview {
    ScrollView {
        MarkdownContentView(markdown: """
        今天天气很好，我去了公园散步。阳光明媚，微风轻拂。

        下午在咖啡馆待了一会儿，读了一本好书。

        晚上和朋友吃了顿饭，聊了很多有趣的话题。**感觉很充实**，希望明天也能这样。
        """)
        .padding()
    }
}
