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
 *
 * 排版规范 (Phase 11.3):
 * - 行间距: lineSpacing(8) (~1.5x)
 * - 段落间距: 20pt
 * - 标题: ## 开头 → .title3.semibold + 额外上方间距
 * - 列表项: 以 - 开头的行 → 圆点 + 缩进
 */
struct MarkdownContentView: View {
    let markdown: String
    
    /// 段落类型
    private enum ParagraphType {
        case heading(String)   // ## 标题（去掉 ## 前缀后的文本）
        case listBlock(String) // 列表块
        case body(String)      // 普通正文
    }
    
    /// 按空行分割并分类段落
    private var typedParagraphs: [ParagraphType] {
        markdown
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { classifyParagraph($0) }
    }
    
    /// 分类段落类型
    private func classifyParagraph(_ text: String) -> ParagraphType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // ## 标题检测
        if trimmed.hasPrefix("## ") {
            let headingText = String(trimmed.dropFirst(3))
            return .heading(headingText)
        }
        
        // 列表块检测（所有行都以 - 开头）
        let lines = trimmed.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let allList = lines.allSatisfy { $0.hasPrefix("- ") }
        if allList && !lines.isEmpty {
            return .listBlock(trimmed)
        }
        
        // 普通正文
        return .body(trimmed)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(typedParagraphs.enumerated()), id: \.offset) { index, paragraph in
                switch paragraph {
                case .heading(let text):
                    renderHeading(text, isFirst: index == 0)
                case .listBlock(let text):
                    renderListBlock(text)
                        .padding(.leading, 4)
                case .body(let text):
                    renderBodyParagraph(text)
                }
            }
        }
    }
    
    // MARK: - Heading
    
    @ViewBuilder
    private func renderHeading(_ text: String, isFirst: Bool) -> some View {
        if let attributedString = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .full
            )
        ) {
            Text(attributedString)
                .textSelection(.enabled)
                .font(.title3)
                .fontWeight(.semibold)
                .lineSpacing(4)
                .padding(.top, isFirst ? 0 : 8)
        } else {
            Text(text)
                .textSelection(.enabled)
                .font(.title3)
                .fontWeight(.semibold)
                .lineSpacing(4)
                .padding(.top, isFirst ? 0 : 8)
        }
    }
    
    // MARK: - Body
    
    @ViewBuilder
    private func renderBodyParagraph(_ text: String) -> some View {
        if let attributedString = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .full
            )
        ) {
            Text(attributedString)
                .textSelection(.enabled)
                .font(.body)
                .lineSpacing(8)
        } else {
            Text(text)
                .textSelection(.enabled)
                .font(.body)
                .lineSpacing(8)
        }
    }
    
    // MARK: - List Block
    
    @ViewBuilder
    private func renderListBlock(_ text: String) -> some View {
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                let content = String(line.dropFirst(2)) // 去掉 "- " 前缀
                if let attributedString = try? AttributedString(
                    markdown: content,
                    options: AttributedString.MarkdownParsingOptions(
                        interpretedSyntax: .full
                    )
                ) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("•")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text(attributedString)
                            .textSelection(.enabled)
                            .font(.body)
                            .lineSpacing(8)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("•")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text(content)
                            .textSelection(.enabled)
                            .font(.body)
                            .lineSpacing(8)
                    }
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        MarkdownContentView(markdown: """
        Wing 的名字承载着双重意象：羽毛笔与翅膀。像羽毛笔一样，用轻盈的笔触捕捉生活的片段；像黄昏时分的猫头鹰收拢翅膀，整理一天的思绪与回忆。它是一个注重隐私、轻量级的 AI 日记应用，让记录与回顾都像羽毛一样轻盈、自由。

        ## Wing 的亮点

        - **本地记录**：所有数据均严格保存在本地，你的思绪只属于你。
        - **支持备份**：提供全量 JSON 导出与恢复，数据安全无忧。
        - **自选模型**：接入多方大模型，选择最适合你的 AI 伙伴。

        ## 如何使用

        - **配置模型**：在设置页面填写你的 API Key，并选择偏好的文风与标题样式。
        - **记录思绪**：像发消息一样，随时随地在"当下"页面输入你的碎片想法。
        - **生成日记**：夜晚来临时，长按底部的"+"号，AI 会为你将碎片整理为排版精美的结构化日记。

        这篇介绍会作为你的第一条日记出现在这里。你可以随时在详情页通过「更多」→「删除」将其删除，或保留作日后参考。

        祝你凭借 Wing 飞向更遥远、更晴朗的明日。
        """)
        .padding()
    }
}
