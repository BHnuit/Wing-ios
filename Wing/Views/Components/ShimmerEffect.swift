//
//  ShimmerEffect.swift
//  Wing
//
//  Created on 2026-02-16.
//

import SwiftUI

/**
 * 微光效果 (ShipSwift)
 *
 * 为内容添加流动的微光动画，用于引导用户点击或表示正在加载。
 */
struct ShimmerEffect<Content: View>: View {
    @State private var animate = false

    var duration: Double = 2.0
    var delay: Double = 1.0

    let content: () -> Content

    init(
        duration: Double = 2.0,
        delay: Double = 1.0,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.duration = duration
        self.delay = delay
        self.content = content
    }

    // 白色微光渐变
    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                .clear,
                .white.opacity(0.1),
                .white.opacity(0.4),
                .white.opacity(0.1),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        content()
            .overlay {
                GeometryReader { geo in
                    let bandWidth = geo.size.width * 0.8
                    gradient
                        .frame(width: bandWidth, height: geo.size.height * 1.5)
                        .rotationEffect(.degrees(20))
                        // 从屏幕左侧外完全移动到右侧外
                        .offset(x: animate ? geo.size.width + bandWidth : -bandWidth * 2)
                        .animation(
                            .linear(duration: duration)
                            .delay(delay)
                            .repeatForever(autoreverses: false),
                            value: animate
                        )
                }
                .mask {
                    content()
                }
            }
            .task {
                // 延迟一帧确保视图加载
                try? await Task.sleep(nanoseconds: 100_000_000)
                animate = true
            }
    }
}

extension View {
    /**
     * 应用微光效果
     */
    func shimmer(duration: Double = 2.0, delay: Double = 1.0) -> some View {
        ShimmerEffect(duration: duration, delay: delay) {
            self
        }
    }
}

#Preview {
    VStack {
        Text("生成日记")
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .shimmer()
    }
    .padding()
}
