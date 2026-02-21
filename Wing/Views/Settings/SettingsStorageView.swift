//
//  SettingsStorageView.swift
//  Wing
//
//  Created on 2026-02-05.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import os

struct SettingsStorageView: View {
    private static let logger = Logger(subsystem: "wing", category: "SettingsStorage")
    @Environment(\.modelContext) private var modelContext
    @State private var showImportFilePicker: Bool = false
    @State private var showImportFolderPicker: Bool = false
    @State private var showReplaceFilePicker: Bool = false
    @State private var showReplaceFolderPicker: Bool = false
    @State private var showReplaceConfirmation: Bool = false
    @State private var showClearConfirmation: Bool = false
    
    @State private var isImporting: Bool = false
    @State private var importMessage: String? = nil
    @State private var showImportAlert: Bool = false
    @State private var exportItem: ExportItem?
    
    var body: some View {
        Form {
            Section {
                Button {
                    Task {
                        await exportJSON()
                    }
                } label: {
                    Label(L("settings.storage.export.json"), systemImage: "square.and.arrow.up") // Revert
                        .foregroundStyle(.primary)
                }
            } header: {
                Text(L("settings.storage.section.export"))
            } footer: {
                Text(L("settings.storage.export.footer"))
            }
            
            Section {
                Button {
                    showImportFilePicker = true
                } label: {
                    Label(L("settings.storage.import.json"), systemImage: "square.and.arrow.down") // Revert
                }
                .fileImporter(isPresented: $showImportFilePicker, allowedContentTypes: [.json, .plainText, .data]) { result in
                    handleImport(result: result, isReplace: false)
                }
                
                Button {
                    showImportFolderPicker = true
                } label: {
                    Label(L("settings.storage.import.folder"), systemImage: "folder") // Revert
                }
                .fileImporter(isPresented: $showImportFolderPicker, allowedContentTypes: [.folder]) { result in
                    handleImportFolder(result: result, isReplace: false)
                }
            } header: {
                Text(L("settings.storage.section.import"))
            } footer: {
                Text(L("settings.storage.import.footer"))
            }
            
            Section {
                Button(role: .destructive) {
                    showReplaceConfirmation = true
                } label: {
                    Label(L("settings.storage.replace"), systemImage: "arrow.triangle.2.circlepath") // Revert font
                }
                .fileImporter(isPresented: $showReplaceFilePicker, allowedContentTypes: [.json, .plainText, .data]) { result in
                    handleImport(result: result, isReplace: true)
                }
                
                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    Label(L("settings.storage.clearAll"), systemImage: "trash") // Revert
                }
            } header: {
                Text(L("settings.storage.section.danger"))
            } footer: {
                Text(L("settings.storage.danger.footer"))
            }
        }
        .navigationTitle(L("settings.storage.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $exportItem) { item in
            ShareSheet(activityItems: [item.url])
                .presentationDetents([.medium, .large])
        }
        // Replace Data Confirmation
        .alert(L("settings.storage.replace.confirm"), isPresented: $showReplaceConfirmation) {
            Button(L("common.cancel"), role: .cancel) { }
            Button(L("settings.storage.replace.action"), role: .destructive) {
                showReplaceFilePicker = true
            }
        } message: {
            Text(L("settings.storage.replace.message"))
        }
        // Clear All Data Confirmation
        .alert(L("settings.storage.clear.confirm"), isPresented: $showClearConfirmation) {
            Button(L("common.cancel"), role: .cancel) { }
            Button(L("settings.storage.clear.action"), role: .destructive) {
                Task { await clearAllData() }
            }
        } message: {
            Text(L("settings.storage.clear.message"))
        }
        .alert(isImporting ? L("common.processing") : (importMessage ?? ""), isPresented: $showImportAlert) {
            Button(L("common.ok"), role: .cancel) { }
        }
        .disabled(isImporting)
        .overlay {
            if isImporting {
                ProgressView(L("settings.storage.processing"))
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(8)
            }
        }
    }
    
    private func exportJSON() async {
        isImporting = true
        defer { isImporting = false }
        do {
            let fileURL = try await DataExportService.shared.exportJSON(context: modelContext)
            exportItem = ExportItem(url: fileURL)
        } catch {
            Self.logger.error("Export JSON failed: \(error)")
            importMessage = String(format: L("settings.storage.exportFailed"), error.localizedDescription)
            showImportAlert = true
        }
    }
    
    private func handleImport(result: Result<URL, Error>, isReplace: Bool) {
        switch result {
        case .success(let url):
            Task {
                await performImport(url: url, isReplace: isReplace)
            }
        case .failure(let error):
            importMessage = String(format: L("settings.storage.fileFailed"), error.localizedDescription)
            showImportAlert = true
        }
    }
    
    private func handleImportFolder(result: Result<URL, Error>, isReplace: Bool) {
        switch result {
        case .success(let url):
            Task {
                await performImportFolder(url: url, isReplace: isReplace)
            }
        case .failure(let error):
            importMessage = String(format: L("settings.storage.folderFailed"), error.localizedDescription)
            showImportAlert = true
        }
    }
    
    private func performImport(url: URL, isReplace: Bool) async {
        isImporting = true
        defer { isImporting = false }
        
        do {
            if isReplace {
                try await DataImportService.shared.replaceData(from: url, context: modelContext)
                importMessage = L("settings.storage.replaceSuccess")
            } else {
                try await DataImportService.shared.importJSON(from: url, context: modelContext)
                importMessage = L("settings.storage.importSuccess")
            }
            showImportAlert = true
        } catch {
            importMessage = String(format: L("settings.storage.importFailed"), error.localizedDescription)
            showImportAlert = true
        }
    }
    
    private func performImportFolder(url: URL, isReplace: Bool) async {
        isImporting = true
        defer { isImporting = false }
        
        do {
            try await DataImportService.shared.importFromFolder(url: url, context: modelContext, replace: isReplace)
            importMessage = L("settings.storage.folderSuccess")
            showImportAlert = true
        } catch {
            importMessage = String(format: L("settings.storage.folderImportFailed"), error.localizedDescription)
            showImportAlert = true
        }
    }
    
    private func clearAllData() async {
        isImporting = true
        defer { isImporting = false }
        
        do {
            // Delete WingEntries
            let entries = try modelContext.fetch(FetchDescriptor<WingEntry>())
            for entry in entries { modelContext.delete(entry) }
            
            // Delete RawFragments
            let fragments = try modelContext.fetch(FetchDescriptor<RawFragment>())
            for fragment in fragments { modelContext.delete(fragment) }
            
            // Delete DailySessions
            let sessions = try modelContext.fetch(FetchDescriptor<DailySession>())
            for session in sessions { modelContext.delete(session) }
            
            // Delete Memories
            let semantics = try modelContext.fetch(FetchDescriptor<SemanticMemory>())
            for memory in semantics { modelContext.delete(memory) }
            let episodics = try modelContext.fetch(FetchDescriptor<EpisodicMemory>())
            for memory in episodics { modelContext.delete(memory) }
            let procedurals = try modelContext.fetch(FetchDescriptor<ProceduralMemory>())
            for memory in procedurals { modelContext.delete(memory) }
            
            try modelContext.save()
            
            // 重置引导页状态
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            
            importMessage = L("settings.storage.cleared")
        } catch {
            importMessage = "Clear failed: \(error.localizedDescription)"
        }
        
        showImportAlert = true
    }
}
