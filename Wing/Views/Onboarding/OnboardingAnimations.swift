//
//  OnboardingAnimations.swift
//  Wing
//
//  Created on 2026-02-20.
//

import SwiftUI

// MARK: - Slide 1 Animation: Wing Logo 高频振动进场
struct WingLogoAnimationView: View {
    @State private var appeared = false
    @State private var vibrateOffset: CGFloat = 0
    @State private var isVibrating = false
    
    /// 振动参数
    private let vibrationAmplitude: CGFloat = 1.5
    private let vibrationCount = 10
    private let vibrationDuration: Double = 0.04
    
    var body: some View {
        Image("WingLogo")
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.accentColor)
            .frame(width: 108, height: 138)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1.0 : 0.92)
            .offset(x: vibrateOffset)
            .onAppear {
                // 阶段 1：淡入 + 缩放
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.2)) {
                    appeared = true
                }
                // 阶段 2：高频振动（蝉翼振翅感）
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(650))
                    await startVibration()
                }
            }
    }
    
    @MainActor
    private func startVibration() async {
        while !Task.isCancelled {
            for i in 0..<vibrationCount {
                let direction: CGFloat = i.isMultiple(of: 2) ? 1 : -1
                // 振幅从强到弱衰减
                let decay = 1.0 - (Double(i) / Double(vibrationCount))
                let currentAmplitude = vibrationAmplitude * CGFloat(decay)
                
                withAnimation(.linear(duration: vibrationDuration)) {
                    vibrateOffset = direction * currentAmplitude
                }
                try? await Task.sleep(for: .milliseconds(Int(vibrationDuration * 1000)))
            }
            // 回到原位
            withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                vibrateOffset = 0
            }
            // 等待 2 秒后重新振动
            try? await Task.sleep(for: .seconds(2))
        }
    }
}

#Preview("Wing Logo") {
    WingLogoAnimationView()
}

// MARK: - Slide 2 Animation: 归拢合成 (Chat Bubbles to Journal)
struct SynthesisAnimationView: View {
    @State private var animateBubbles = false
    @State private var pressRecord = false
    @State private var recordProgress: CGFloat = 0.0
    @State private var particleProgress: CGFloat = 0.0
    @State private var pulseTab = false
    
    var body: some View {
        ZStack { // 外层包裹，用于放置全局粒子
            VStack(spacing: 24) {
                // 上方：方形白色画布区域
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(uiColor: .systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
                    
                    // 模拟的聊天气泡
                    VStack(spacing: 14) {
                        ChatBubbleShape(text: "今天看了很棒的晚霞")
                            .offset(y: animateBubbles ? 0 : 20)
                            .opacity(animateBubbles ? 1 : 0)
                            .animation(.easeOut(duration: 0.6).delay(0.2), value: animateBubbles)
                        
                        ChatBubbleShape(text: "不过下班回家的路上好堵...")
                            .offset(y: animateBubbles ? 0 : 20)
                            .opacity(animateBubbles ? 1 : 0)
                            .animation(.easeOut(duration: 0.6).delay(0.4), value: animateBubbles)
                        
                        ChatBubbleShape(text: "又吃了一顿减脂餐！")
                            .offset(y: animateBubbles ? 0 : 20)
                            .opacity(animateBubbles ? 1 : 0)
                            .animation(.easeOut(duration: 0.6).delay(0.6), value: animateBubbles)
                    }
                    .padding(.horizontal, 20)
                }
                .aspectRatio(1.0, contentMode: .fit) // 强制为正方形
                
                // 下方：分离的图标栏区域，占据左右两侧
                HStack {
                    // 左侧：日记 Tab
                    Image(systemName: "book.pages.fill")
                        .foregroundColor(pulseTab ? .accentColor : .secondary)
                        .font(.system(size: 28)) // 稍微放大一点增加质感
                        .scaleEffect(pulseTab ? 1.3 : 1.0)
                        // 用于辅助粒子找准终点位置
                        .padding(.leading, 12)
                    
                    Spacer()
                    
                    // 右侧：+号记录 Tab
                    ZStack {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 3)
                        
                        Circle()
                            .trim(from: 0, to: recordProgress)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 24))
                            .scaleEffect(pressRecord ? 0.9 : 1.0)
                    }
                    .frame(width: 48, height: 48)
                    .padding(.trailing, 12)
                }
                .padding(.horizontal, 16)
            }
            
            // 粒子效果覆盖在最顶层，不会被子节点裁剪
            GeometryReader { geo in
                ParticlePathView(progress: particleProgress, canvasSize: geo.size)
            }
            .allowsHitTesting(false)
        }
        .padding(.horizontal, 32) // 控制整体宽度
        .onAppear {
            startAnimationCycle()
        }
    }
    
    private func startAnimationCycle() {
        animateBubbles = false
        pressRecord = false
        recordProgress = 0.0
        particleProgress = 0.0
        pulseTab = false
        
        // 阶段 1：气泡出现
        withAnimation { animateBubbles = true }
        
        // 阶段 2：长按记录
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.2)) { pressRecord = true }
            withAnimation(.linear(duration: 1.0)) { recordProgress = 1.0 }
        }
        
        // 阶段 3：粒子飞向日记
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            withAnimation(.easeInOut(duration: 0.2)) {
                pressRecord = false
                recordProgress = 0.0
            }
            withAnimation(.easeInOut(duration: 0.8)) { animateBubbles = false }
            withAnimation(.linear(duration: 0.8)) { particleProgress = 1.0 }
        }
        
        // 阶段 4：日记 Icon 脉冲跳动多次
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
            particleProgress = 0.0
            // 跳动 3 次
            for i in 0..<3 {
                let delay = Double(i) * 0.35
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { pulseTab = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { pulseTab = false }
                    }
                }
            }
        }
        
        // 阶段 5：重置循环
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            startAnimationCycle()
        }
    }
}

struct ChatBubbleShape: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            // 可以带有一点微光或边界感提升精致度
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

// 粒子路径 — 基于全局空间规划坐标
struct ParticlePathView: View, Animatable {
    var progress: CGFloat
    var canvasSize: CGSize
    
    // 关键修正：将 progress 暴露为可动画属性
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    var body: some View {
        Canvas { context, size in
            guard progress > 0 && progress <= 1 else { return }
            
            let width = size.width
            // 正方形画布的边长等于外层的宽度
            let canvasBoxHeight = width
            
            // 三个气泡的最初 Y 坐标偏移（分散在画布中上部区域）
            let bubbleYPositions: [CGFloat] = [
                canvasBoxHeight * 0.3,
                canvasBoxHeight * 0.5,
                canvasBoxHeight * 0.7
            ]
            
            // 终点：x是在左侧日记按钮区域（大概为 36），y 是画布高度 + HStack 的顶端边距 24 + HStack 中间位置大约 24
            let end = CGPoint(x: 36, y: canvasBoxHeight + 48)
            
            for (index, bubbleY) in bubbleYPositions.enumerated() {
                // 修改此处让 localProgress 可以达到 1.0 并多停留极短时间，避免最后一刻立刻消失
                let localProgress = max(0, min(1.0, progress * 1.3 - CGFloat(index) * 0.15))
                if localProgress > 0 && localProgress <= 1 {
                    // 起点：气泡右侧边缘
                    let start = CGPoint(x: width - 40, y: bubbleY)
                    // 控制点往下方发散，增加抛物线张力
                    let control = CGPoint(x: width * 0.2, y: canvasBoxHeight * 0.9)
                    
                    let position = calculateBezierPoint(start: start, control: control, end: end, t: localProgress)
                    
                    // 核心蓝点
                    context.fill(
                        Path(ellipseIn: CGRect(x: position.x - 4, y: position.y - 4, width: 8, height: 8)),
                        with: .color(.accentColor)
                    )
                    // 光晕
                    context.fill(
                        Path(ellipseIn: CGRect(x: position.x - 10, y: position.y - 10, width: 20, height: 20)),
                        with: .color(.accentColor.opacity(0.3))
                    )
                    
                    // 尾迹
                    if localProgress > 0.1 {
                        let trail = calculateBezierPoint(start: start, control: control, end: end, t: localProgress - 0.08)
                        context.fill(
                            Path(ellipseIn: CGRect(x: trail.x - 2.5, y: trail.y - 2.5, width: 5, height: 5)),
                            with: .color(.accentColor.opacity(0.5))
                        )
                    }
                }
            }
        }

    }
    
    private func calculateBezierPoint(start: CGPoint, control: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        let x = pow(1-t, 2) * start.x + 2 * (1-t) * t * control.x + pow(t, 2) * end.x
        let y = pow(1-t, 2) * start.y + 2 * (1-t) * t * control.y + pow(t, 2) * end.y
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Slide 3 Animation: 记忆生长
struct MemoryGrowthAnimationView: View {
    @State private var showCard1 = false
    @State private var showCard2 = false
    @State private var showCard3 = false
    @State private var showCard4 = false
    @State private var showCard5 = false
    @State private var pulseBook = false
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // 圆角白底投影卡片
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
                
                // 中心日记本 Icon
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "book.pages.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 28))
                            .scaleEffect(pulseBook ? 1.08 : 1.0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseBook)
                    )
                
                // 记忆胶囊
                Group {
                    MemoryPillView(text: "25岁")
                        .offset(x: -70, y: -90)
                        .opacity(showCard1 ? 1 : 0)
                        .scaleEffect(showCard1 ? 1 : 0.8)
                    
                    MemoryPillView(text: "养了只猫叫奈奈")
                        .offset(x: 50, y: -110)
                        .opacity(showCard2 ? 1 : 0)
                        .scaleEffect(showCard2 ? 1 : 0.8)
                    
                    MemoryPillView(text: "职场白领")
                        .offset(x: 80, y: -20)
                        .opacity(showCard3 ? 1 : 0)
                        .scaleEffect(showCard3 ? 1 : 0.8)
                    
                    MemoryPillView(text: "喜欢拉面")
                        .offset(x: -70, y: 30)
                        .opacity(showCard4 ? 1 : 0)
                        .scaleEffect(showCard4 ? 1 : 0.8)
                    
                    MemoryPillView(text: "看过的电影：好日子")
                        .offset(x: 20, y: 90)
                        .opacity(showCard5 ? 1 : 0)
                        .scaleEffect(showCard5 ? 1 : 0.8)
                }
            }
            .aspectRatio(1.0, contentMode: .fit)
            
            // 底部占位符以对齐 Slide 2
            Color.clear.frame(height: 48)
        }
        .padding(.horizontal, 32) // 与 Slide 2 等宽
        .onAppear {
            pulseBook = true
            startAnimationCycle()
        }
    }
    
    /// 使用 DispatchQueue 逐个延迟触发，确保每个胶囊都有独立的弹簧动画
    private func startAnimationCycle() {
        // 依次弹出每个胶囊
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { showCard1 = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { showCard2 = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { showCard3 = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { showCard4 = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { showCard5 = true }
        }
        
        // 全部消失后重新循环
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            withAnimation(.easeInOut(duration: 0.4)) {
                showCard1 = false
                showCard2 = false
                showCard3 = false
                showCard4 = false
                showCard5 = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                startAnimationCycle()
            }
        }
    }
}

struct MemoryPillView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 3)
    }
}
