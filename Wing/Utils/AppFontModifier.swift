//
//  AppFontModifier.swift
//  Wing
//
//  Created on 2026-02-12.
//

import SwiftUI
import SwiftData

/**
 * 全局字号修饰符
 * 监听 AppSettings 中的字号设置，并应用到视图层级
 */
struct AppFontModifier: ViewModifier {
    @Query private var appSettings: [AppSettings]
    
    private var settings: AppSettings? {
        appSettings.first
    }
    
    func body(content: Content) -> some View {
        let sizeMultiplier = getSizeMultiplier()
        
        if sizeMultiplier == 1.0 {
            content
        } else {
            content
                .environment(\.font, Font.system(size: 17 * sizeMultiplier))
        }
    }
    
    private func getSizeMultiplier() -> CGFloat {
        guard let settings = settings else { return 1.0 }
        switch settings.fontSize {
        case .small:
            return 0.9
        case .medium:
            return 1.0
        case .large:
            return 1.15
        }
    }
}

extension View {
    func appFont() -> some View {
        modifier(AppFontModifier())
    }
}
