//
//  DataSharingConsentView.swift
//  Wing
//
//  Created on 2026-02-25.
//

import SwiftUI

/**
 * 数据共享同意弹窗
 *
 * 根据 Apple 审核指南 5.1.1(i) 和 5.1.2(i) 的要求，
 * 在用户首次使用 AI 功能前，明确告知：
 * - 发送了哪些数据
 * - 数据接收方是谁
 * - 数据用途
 * 并在用户明确同意后才允许使用 AI 功能。
 */
struct DataSharingConsentView: View {
    @Environment(\.dismiss) private var dismiss
    let providerName: String
    let onConsent: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 标题区
                    VStack(spacing: 8) {
                        Image(systemName: "hand.raised.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.accentColor)
                        
                        Text(L("consent.title"))
                            .font(.system(size: 24, weight: .bold))
                            .multilineTextAlignment(.center)
                        
                        Text(L("consent.subtitle"))
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    
                    // 第一区块：发送的数据
                    consentSection(
                        icon: "doc.text",
                        title: L("consent.data.title"),
                        items: [
                            L("consent.data.fragments"),
                            L("consent.data.imageDesc"),
                            L("consent.data.memories")
                        ]
                    )
                    
                    // 第二区块：接收方
                    consentSection(
                        icon: "arrow.up.right.circle",
                        title: L("consent.recipient.title"),
                        items: [
                            String(format: L("consent.recipient.provider"), providerName),
                            L("consent.recipient.directOnly")
                        ]
                    )
                    
                    // 第三区块：用途
                    consentSection(
                        icon: "sparkles",
                        title: L("consent.purpose.title"),
                        items: [
                            L("consent.purpose.journal"),
                            L("consent.purpose.memory")
                        ]
                    )
                    
                    // 隐私政策链接
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Text(L("consent.privacy.note"))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Link(L("consent.privacy.link"), destination: URL(string: "https://BHnuit.github.io/Wing-ios/privacy.html")!)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 120) // 给底部按钮留空间
            }
            .overlay(alignment: .bottom) {
                // 底部按钮区
                VStack(spacing: 12) {
                    Button {
                        onConsent()
                        dismiss()
                    } label: {
                        Text(L("consent.button.agree"))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.8))
                                    .background(.ultraThinMaterial, in: Capsule())
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                            .shadow(color: Color.accentColor.opacity(0.4), radius: 15, y: 8)
                    }
                    
                    Button {
                        onDecline()
                        dismiss()
                    } label: {
                        Text(L("consent.button.decline"))
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                .background(
                    LinearGradient(
                        colors: [
                            Color(uiColor: .systemBackground).opacity(0),
                            Color(uiColor: .systemBackground)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                    .allowsHitTesting(false),
                    alignment: .top
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onDecline()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }
    
    // MARK: - Components
    
    private func consentSection(icon: String, title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        Text(item)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.leading, 24)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
    }
}

#Preview {
    DataSharingConsentView(
        providerName: "Gemini",
        onConsent: {},
        onDecline: {}
    )
}
