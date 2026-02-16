//
//  SynthesisDesignPreview.swift
//  Wing
//
//  Created for Design Review.
//

import SwiftUI

struct SynthesisDesignPreview: View {
    var body: some View {
        VStack(spacing: 50) {
            Text("Synthesis Progress Design Options")
                .font(.title2.bold())
                .padding(.top, 40)
            
            // Row 1: Progress Styles
            VStack(spacing: 20) {
                Text("Progress Style (at 65%)").font(.headline).foregroundStyle(.secondary)
                HStack(spacing: 60) {
                    VStack {
                        DesignComponent(progress: 0.65, style: .ring)
                        Text("Option A: Ring").font(.caption).bold()
                    }
                    
                    VStack {
                        DesignComponent(progress: 0.65, style: .pie)
                        Text("Option B: Pie").font(.caption).bold()
                    }
                }
            }
            
            Divider().padding(.horizontal)
            
            // Row 2: Completion Icons
            VStack(spacing: 20) {
                Text("Completion Icon Options").font(.headline).foregroundStyle(.secondary)
                HStack(spacing: 40) {
                    VStack {
                        DesignComponent(isComplete: true, icon: "sparkles")
                        Text("Sparkles").font(.caption)
                    }
                    VStack {
                        DesignComponent(isComplete: true, icon: "book.closed.fill")
                        Text("Book").font(.caption)
                    }
                    VStack {
                        DesignComponent(isComplete: true, icon: "checkmark")
                        Text("Check").font(.caption)
                    }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

enum ProgressStyle { case ring, pie }

struct DesignComponent: View {
    var progress: Double = 0.0
    var style: ProgressStyle = .ring
    var isComplete: Bool = false
    var icon: String = "sparkles"
    
    var body: some View {
        ZStack {
            // Background Shadow
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 60, height: 60)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            
            if isComplete {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.bounce, value: isComplete)
            } else {
                if style == .ring {
                    // Track
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: 54, height: 54)
                    
                    // Progress
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 54, height: 54)
                        .rotationEffect(.degrees(-90))
                    
                    // Center Icon (Wand)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.secondary)
                        .opacity(0.7)
                        
                } else {
                     // Pie Style
                     Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 54, height: 54)
                    
                    GeometryReader { geo in
                        Path { path in
                            let width = geo.size.width
                            let height = geo.size.height
                            path.move(to: CGPoint(x: width/2, y: height/2))
                            path.addArc(center: CGPoint(x: width/2, y: height/2),
                                        radius: width/2,
                                        startAngle: .degrees(-90),
                                        endAngle: .degrees(-90 + (progress * 360)),
                                        clockwise: false)
                            path.closeSubpath()
                        }
                        .fill(Color.accentColor.opacity(0.2))
                    }
                    .frame(width: 54, height: 54)
                    
                    // Percentage Text
                    Text("\(Int(progress * 100))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .frame(width: 80, height: 80)
    }
}

#Preview {
    SynthesisDesignPreview()
}
