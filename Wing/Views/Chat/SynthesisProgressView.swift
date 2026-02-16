//
//  SynthesisProgressView.swift
//  Wing
//
//  Created on 2026-01-29.
//

import SwiftUI

/**
 * 日记合成进度视图
 *
 * 分步文案反馈 + 自动轮换鼓励语，缓解用户等待焦虑
 */
struct SynthesisProgressView: View {
    let progress: SynthesisProgress
    
    // 自动轮换的鼓励语
    @State private var encouragementIndex = 0
    
    private var encouragements: [String] {
        [
            L("synthesis.weaving"),
            L("synthesis.owl.thinking"),
            L("synthesis.organizing"),
            L("synthesis.ai.creating"),
            L("synthesis.wait")
        ]
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // 动画图标
            progressIcon
                .font(.system(size: 60))
                .foregroundStyle(iconColor)
            
            // 进度文案
            VStack(spacing: 8) {
                Text(displayMessage)
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.3), value: encouragementIndex)
                
                // 生成中时显示提示
                if case .generating = progress {
                    Text(L("synthesis.time.hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // 加载指示器（非完成状态时显示）
            if !isCompleted {
                ThinkingIndicator(dotColor: .accentColor)
                    .padding(.top, 8)
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
        .shadow(radius: 10)
        .onAppear {
            startEncouragementTimer()
        }
    }
    
    // MARK: - Computed Properties
    
    private var displayMessage: String {
        switch progress {
        case .generating:
            return encouragements[encouragementIndex]
        default:
            return progress.localizedMessage
        }
    }
    
    @ViewBuilder
    private var progressIcon: some View {
        switch progress {
        case .started:
            Image(systemName: "sparkles")
                .symbolEffect(.pulse)
        case .generating:
            Image(systemName: "wand.and.stars")
                .symbolEffect(.wiggle)
        case .saving:
            Image(systemName: "brain.head.profile")
                .symbolEffect(.pulse)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
        }
    }
    
    private var iconColor: Color {
        switch progress {
        case .completed:
            return .green
        case .failed:
            return .red
        default:
            return .blue
        }
    }
    
    private var isCompleted: Bool {
        switch progress {
        case .completed, .failed:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Timer
    
    private func startEncouragementTimer() {
        // 每 3 秒切换鼓励语
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
            if case .completed = progress {
                timer.invalidate()
                return
            }
            if case .failed = progress {
                timer.invalidate()
                return
            }
            
            withAnimation {
                encouragementIndex = (encouragementIndex + 1) % encouragements.count
            }
        }
    }
}

#Preview("Started") {
    ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
        
        SynthesisProgressView(progress: .started)
    }
}

#Preview("Generating") {
    ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
        
        SynthesisProgressView(progress: .generating)
    }
}

#Preview("Completed") {
    ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
        
        SynthesisProgressView(progress: .completed(entryId: UUID()))
    }
}
