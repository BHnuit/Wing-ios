//
//  SettingsStorageView.swift
//  Wing
//
//  Created on 2026-02-05.
//

import SwiftUI
import SwiftData

struct SettingsStorageView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var exportItem: ExportItem?
    @State private var showResetConfirmation: Bool = false
    
    var body: some View {
        Form {
            Section {
                Button {
                    Task {
                        await exportJSON()
                    }
                } label: {
                    Label("导出完整备份 (.json)", systemImage: "square.and.arrow.up")
                        .foregroundStyle(.primary)
                }
            } header: {
                Text("备份与导出")
            } footer: {
                Text("完整备份包含所有的日记、碎片以及图片数据。")
            }
            
            Section {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label("清空所有数据", systemImage: "trash")
                }
            } header: {
                Text("危险区域")
            }
        }
        .navigationTitle("存储管理")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $exportItem) { item in
            ShareSheet(activityItems: [item.url])
                .presentationDetents([.medium, .large])
        }
        .alert("确定要清空所有数据吗？", isPresented: $showResetConfirmation) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                Task {
                    await clearAllData()
                }
            }
        } message: {
            Text("此操作不可恢复，请谨慎操作。建议先进行备份。")
        }
        .toolbar {
            #if DEBUG
            ToolbarItem(placement: .topBarTrailing) {
                Button("注入测试数据") {
                    Task {
                        await TestDataInjector.shared.injectTestData(context: modelContext)
                    }
                }
            }
            #endif
        }
    }
    
    private func exportJSON() async {
        do {
            let fileURL = try await DataExportService.shared.exportJSON(context: modelContext)
            exportItem = ExportItem(url: fileURL)
        } catch {
            print("Export JSON failed: \(error)")
            // TODO: Show Error Toast
        }
    }
    
    private func clearAllData() async {
        // Implement clear logic here, e.g. via TestDataInjector or direct context deletion
        // For now, rely on clean uninstall or manual deletion in dev
        print("Clear data requested")
        await TestDataInjector.shared.clearAllData(context: modelContext)
    }
}
