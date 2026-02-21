//
//  SplashScreenView.swift
//  Wing
//
//  Created on 2026-02-21.
//

import SwiftUI

/// 启动屏视图
/// 复用 Onboarding Slide 1 的 `WingLogoAnimationView`（三笔画 Logo 绘制动画），
/// 动画完成后通过回调通知父视图淡出过渡。
struct SplashScreenView: View {
    let onFinished: () -> Void
    
    @State private var opacity: Double = 1.0
    
    // Logo 三笔画总时长约 2.5 秒 (1.2 + 0.8 + 0.5)
    private let animationDuration: Double = 2.8
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            WingLogoAnimationView()
        }
        .opacity(opacity)
        .task {
            // 等待 Logo 绘制完成
            try? await Task.sleep(for: .seconds(animationDuration))
            
            // 淡出过渡
            withAnimation(.easeOut(duration: 0.4)) {
                opacity = 0
            }
            
            // 等淡出结束后回调
            try? await Task.sleep(for: .seconds(0.4))
            onFinished()
        }
    }
}

#Preview {
    SplashScreenView(onFinished: {})
}
