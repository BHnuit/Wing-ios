//
//  ThinkingIndicator.swift
//  Wing
//
//  Created on 2026-02-16.
//

import SwiftUI

/**
 * 思考指示器 (ShipSwift)
 *
 * 三个跳动的小圆点，用于表示 AI 正在思考或生成日记。
 */
struct ThinkingIndicator: View {
    // MARK: - Configurable Parameters

    var dotSize: CGFloat = 6
    var dotColor: Color = .secondary
    var spacing: CGFloat = 4

    // MARK: - Body

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.3)) { timeline in
            let phase = Int(timeline.date.timeIntervalSinceReferenceDate / 0.3) % 3
            HStack(spacing: spacing) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(dotColor)
                        .frame(width: dotSize, height: dotSize)
                        .offset(y: phase == index ? -(dotSize * 0.5) : 0)
                        .animation(.easeInOut(duration: 0.2), value: phase)
                }
            }
        }
    }
}

#Preview {
    ThinkingIndicator()
        .padding()
}
