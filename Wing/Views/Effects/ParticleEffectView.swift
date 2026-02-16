//
//  ParticleEffectView.swift
//  Wing
//
//  Created on 2026-02-16.
//

import SwiftUI

/**
 * 粒子特效视图
 *
 * 用于“日记收拢”过程中的视觉反馈：
 * 粒子从各个消息气泡（sourceRects）飞向日记入口（targetRect）。
 */
struct ParticleEffectView: View {
    /// 是否激活特效
    var isActive: Bool
    
    /// 粒子源位置列表（气泡 Frame）
    var sourceRects: [CGRect]
    
    /// 目标位置（日记 Icon Frame）
    var targetRect: CGRect
    
    /// 全局几何代理（用于坐标转换）
    var geometry: GeometryProxy
    
    @State private var particles: [ParticleState] = []
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for particle in particles {
                    // Draw particle
                    let pos = particle.currentPosition
                    
                    let rect = CGRect(
                        x: pos.x - 2,
                        y: pos.y - 2,
                        width: 4,
                        height: 4
                    )
                    
                    context.opacity = particle.opacity
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.accentColor)
                    )
                }
            }
            .onChange(of: timeline.date) { oldDate, newDate in
                updateParticles(deltaTime: newDate.timeIntervalSince(oldDate))
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                spawnParticles()
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            if isActive {
                spawnParticles()
            }
        }
    }
    
    private func spawnParticles() {
        // 如果没有气泡源，使用默认右下角位置 (Fallback)
        let effectiveSources: [CGRect]
        if sourceRects.isEmpty {
            effectiveSources = [CGRect(x: geometry.size.width - 60, y: geometry.size.height - 100, width: 50, height: 50)]
        } else {
            effectiveSources = sourceRects
        }
        
        let targetCenter = CGPoint(x: targetRect.midX, y: targetRect.midY)
        
        // 总粒子数限制，分布到各气泡
        let totalParticles = 40
        let particlesPerSource = max(1, totalParticles / effectiveSources.count)
        
        var newParticles: [ParticleState] = []
        
        for source in effectiveSources {
            // 将 source 坐标转换为本地坐标 (假设 sourceRects 已经是全局坐标，而 Canvas 也是全屏覆盖)
            // 注意：AnchorPreference 传递的 geometry[anchor] 通常是相对于其父视图的。
            // 如果 MainTabView 的 overlay 是全屏的，那么坐标应该是一致的。
            
            for _ in 0..<particlesPerSource {
                let startX = CGFloat.random(in: source.minX...source.maxX)
                let startY = CGFloat.random(in: source.minY...source.maxY)
                let startPoint = CGPoint(x: startX, y: startY)
                
                newParticles.append(
                    ParticleState(
                        start: startPoint,
                        end: targetCenter,
                        delay: Double.random(in: 0...0.3),
                        speed: Double.random(in: 1.0...1.5)
                    )
                )
            }
        }
        
        particles = newParticles
    }
    
    private func updateParticles(deltaTime: TimeInterval) {
        let dt = min(deltaTime, 0.1)
        for i in particles.indices {
            particles[i].update(deltaTime: dt)
        }
    }
}

// MARK: - Particle State Model

private struct ParticleState: Identifiable {
    let id = UUID()
    var progress: Double = 0.0
    var opacity: Double = 1.0
    var delay: Double
    var speed: Double
    
    let start: CGPoint
    let end: CGPoint
    let controlPoint: CGPoint
    
    init(start: CGPoint, end: CGPoint, delay: Double, speed: Double) {
        self.start = start
        self.end = end
        self.delay = delay
        self.speed = speed
        
        // Calculate a random control point for the arc
        // Arc should go UP significantly to look like a throw
        // Logic: Find midpoint, then raise Y (decrease value)
        let midX = (start.x + end.x) / 2
        let midY = (start.y + end.y) / 2
        
        // Height depends on distance
        let distance = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2))
        let arcHeight = distance * 0.3 // arch is 30% of distance
        
        self.controlPoint = CGPoint(x: midX, y: midY - arcHeight)
    }
    
    var currentPosition: CGPoint {
        calculateBezier(t: max(0, min(1, progress)))
    }
    
    mutating func update(deltaTime: TimeInterval) {
        if delay > 0 {
            delay -= deltaTime
            return
        }
        
        if progress < 1.0 {
            progress += deltaTime * speed
        } else {
            opacity = max(0, opacity - (deltaTime * 5))
        }
    }
    
    private func calculateBezier(t: Double) -> CGPoint {
        let u = 1 - t
        let tt = t * t
        let uu = u * u
        
        let p0 = start
        let p1 = controlPoint
        let p2 = end
        
        let x = uu * p0.x + 2 * u * t * p1.x + tt * p2.x
        let y = uu * p0.y + 2 * u * t * p1.y + tt * p2.y
        
        return CGPoint(x: x, y: y)
    }
}
