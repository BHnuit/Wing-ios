//
//  EmptyStateView.swift
//  Wing
//
//  Created on 2026-02-19.
//

import SwiftUI

/// A reusable view for displaying empty states, styled to match Apple's native design (e.g., Notes, Photos).
struct EmptyStateView: View {
    let systemImage: String
    let title: String?
    let description: String?
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 4)
            
            if let title {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
            
            if let description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Journal Empty State") {
    EmptyStateView(
        systemImage: "book",
        title: "暂无日记", // Localized key: "journal.empty"
        description: "从“当下”记录你的想法，生成第一篇日记" // Localized key: "journal.empty.hint"
    )
}

#Preview("Memory Empty State") {
    EmptyStateView(
        systemImage: "brain",
        title: "无语义记忆", // Localized key: "settings.memory.semantic.empty"
        description: "当您的日记积累到一定程度，AI 将自动提取语义记忆" // Localized key: "settings.memory.semantic.empty.desc"
    )
}

#Preview("Notes Style Reference") {
    // Mimicking the Apple Notes empty state style
    EmptyStateView(
        systemImage: "note.text",
        title: "无备忘录",
        description: nil
    )
}
