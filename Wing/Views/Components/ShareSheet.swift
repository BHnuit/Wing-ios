//
//  ShareSheet.swift
//  Wing
//
//  Created on 2026-02-01.
//

import SwiftUI
import UIKit

/**
 * 导出项包装器，用于 sheet(item:)
 */
struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

/**
 * 通用分享表格
 */
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
