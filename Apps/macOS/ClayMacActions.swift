import AppKit
import ClayCore
import SwiftUI

/// Presentation state and actions shared by the window and its menu commands.
/// Document content continues to live exclusively in ClayStore.
@MainActor
final class ClayMacActions: ObservableObject {
    @Published var isImportPresented = false
    @Published var isExportPresented = false
    @Published var exportDocument: MarkdownFile?
    @Published var exportFilename = "Untitled.md"
    @Published var searchRequest = 0
    @Published var isTerminating = false

    private var importTasks: [UUID: Task<Void, Never>] = [:]

    func newScratchpad(in store: ClayStore) {
        guard !isTerminating else { return }
        store.selectSection(.scratchpads)
        store.collectionFilter = nil
        store.query = ""
        store.selectedDocumentID = store.createDocument(section: .scratchpads)
    }

    func search(in store: ClayStore) {
        guard !isTerminating else { return }
        store.isFocusMode = false
        searchRequest += 1
    }

    func importDocuments(from urls: [URL], into store: ClayStore) {
        guard !isTerminating, !urls.isEmpty else { return }
        let token = UUID()
        importTasks[token] = Task { @MainActor [weak self] in
            await store.importDocuments(from: urls)
            self?.importTasks[token] = nil
        }
    }

    /// Quit must also wait for a source file that is still being imported.
    func finishPendingImports() async {
        while !importTasks.isEmpty {
            let pending = Array(importTasks.values)
            for task in pending { await task.value }
        }
    }

    func export(id: UUID, from store: ClayStore) {
        guard !isTerminating,
              let document = store.document(id: id),
              let data = store.markdownData(for: id) else { return }

        exportFilename = MarkdownFile.safeFilename(document.displayTitle)
        exportDocument = MarkdownFile(data: data)
        isExportPresented = true
    }

    func trash(id: UUID, in store: ClayStore) {
        guard !isTerminating else { return }
        store.trash(id: id)
    }

    func showLibraryFolder(in store: ClayStore, deletedDocuments: Bool = false) {
        guard let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            store.errorMessage = "Clay couldn’t locate your Application Support folder."
            return
        }

        var folder = supportURL.appendingPathComponent("Clay/Library", isDirectory: true)
        if deletedDocuments {
            folder.appendPathComponent("Trash", isDirectory: true)
        }
        guard FileManager.default.fileExists(atPath: folder.path) else {
            store.errorMessage = deletedDocuments
                ? "There are no deleted documents to show yet."
                : "Your library folder will appear after Clay saves your first document."
            return
        }
        if !NSWorkspace.shared.open(folder) {
            store.errorMessage = "Clay couldn’t open the library folder in Finder."
        }
    }

    func reportFileError(_ error: Error, in store: ClayStore) {
        let cocoaError = error as NSError
        guard !(cocoaError.domain == NSCocoaErrorDomain && cocoaError.code == NSUserCancelledError) else {
            return
        }
        store.errorMessage = error.localizedDescription
    }
}
