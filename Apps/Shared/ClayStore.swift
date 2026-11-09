import Foundation
import Combine
import ClayCore

/// One store is shared by all windows of an installation. All user edits happen
/// on the main actor; disk operations are serialized by LibraryRepository.
@MainActor
final class ClayStore: ObservableObject {
    @Published private(set) var documents: [WritingDocument] = []
    @Published var selectedSection: WritingSection = .scratchpads
    @Published var selectedDocumentID: UUID?
    @Published var query = ""
    @Published var collectionFilter: String?
    @Published var isFocusMode = false
    @Published var errorMessage: String?
    @Published private(set) var saveStatus = "Loading…"

    private let repository: LibraryRepository
    private var loadingTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var writerTask: Task<Void, Never>?
    private var writerToken: UUID?
    private var trashTasks: [UUID: Task<Void, Never>] = [:]
    private var revisions: [UUID: UInt64] = [:]
    private var dirtyIDs = Set<UUID>()
    private var failedRevisions: [UUID: UInt64] = [:]
    private var pendingTrashIDs = Set<UUID>()
    private var deletedIDs = Set<UUID>()
    private var isLoading = true
    private var loadFailed = false

    init(rootURL: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        let library = rootURL ?? support
            .appendingPathComponent("Clay", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
        repository = LibraryRepository(rootURL: library)
        beginLoading()
    }

    var visibleDocuments: [WritingDocument] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return documents.filter { document in
            guard document.section == selectedSection else { return false }
            if let collectionFilter,
               document.collection.trimmingCharacters(in: .whitespacesAndNewlines) != collectionFilter {
                return false
            }
            return search.isEmpty
                || document.displayTitle.localizedCaseInsensitiveContains(search)
                || document.text.localizedCaseInsensitiveContains(search)
                || document.collection.localizedCaseInsensitiveContains(search)
        }.sorted(by: Self.documentOrder)
    }

    var collections: [String] {
        let names = documents.map { $0.collection.trimmingCharacters(in: .whitespacesAndNewlines) }
        return Set(names.filter { !$0.isEmpty }).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var selectedDocument: WritingDocument? {
        guard let selectedDocumentID else { return nil }
        return document(id: selectedDocumentID)
    }

    func document(id: UUID) -> WritingDocument? {
        documents.first { $0.id == id }
    }

    @discardableResult
    func createDocument(section: WritingSection = .scratchpads) -> UUID {
        let now = Date()
        let document = WritingDocument(
            section: section,
            collection: collectionFilter ?? "",
            createdAt: now,
            updatedAt: now
        )
        documents.append(document)
        revisions[document.id] = 1
        dirtyIDs.insert(document.id)
        selectedSection = section
        query = ""
        selectedDocumentID = document.id
        scheduleSave()
        return document.id
    }

    func selectSection(_ section: WritingSection) {
        selectedSection = section
        collectionFilter = nil
        query = ""
        if selectedDocument?.section != section {
            selectedDocumentID = visibleDocuments.first?.id
        }
    }

    func updateTitle(id: UUID, value: String) {
        edit(id: id) { $0.title = value }
    }

    func updateText(id: UUID, value: String) {
        edit(id: id) { $0.text = value }
    }

    func updateCollection(id: UUID, value: String) {
        edit(id: id) { $0.collection = value }
    }

    func togglePin(id: UUID) {
        edit(id: id) { $0.pinned.toggle() }
    }

    func move(id: UUID, to section: WritingSection) {
        guard !pendingTrashIDs.contains(id), document(id: id) != nil else { return }
        edit(id: id) { $0.section = section }
        if selectedDocumentID == id {
            selectedSection = section
            collectionFilter = nil
            query = ""
        }
    }

    /// Keep the document in memory until its latest text has safely reached
    /// Trash. A failed move therefore leaves the writing available to retry.
    func trash(id: UUID) {
        guard !pendingTrashIDs.contains(id), let snapshot = document(id: id) else { return }
        debounceTask?.cancel()
        debounceTask = nil
        pendingTrashIDs.insert(id)
        dirtyIDs.remove(id)
        failedRevisions[id] = nil
        revisions[id, default: 0] &+= 1
        refreshSaveStatus()

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            if let loadingTask = self.loadingTask { await loadingTask.value }
            do {
                try await self.repository.trash(snapshot)
                self.documents.removeAll { $0.id == id }
                self.deletedIDs.insert(id)
                self.revisions[id] = nil
                self.dirtyIDs.remove(id)
                self.failedRevisions[id] = nil
                if self.selectedDocumentID == id {
                    self.selectedDocumentID = self.visibleDocuments.first?.id
                }
            } catch {
                // Do not automatically retry a destructive intent later. The
                // user can retry saving, then explicitly try moving to Trash.
                self.dirtyIDs.insert(id)
                self.failedRevisions[id] = self.revisions[id, default: 0]
                self.report("Couldn’t move “\(snapshot.displayTitle)” to Trash. Your writing is still here. \(error.localizedDescription)")
            }
            self.pendingTrashIDs.remove(id)
            self.trashTasks[id] = nil
            self.refreshSaveStatus()
            if self.hasEligibleWrites { self.scheduleSave() }
        }
        trashTasks[id] = task
    }

    /// Imports go into the selected section and select the last imported file.
    /// Security-scoped URLs stay open for the complete read on a background task.
    func importDocuments(from urls: [URL]) async {
        guard !urls.isEmpty else { return }
        let destination = selectedSection
        let destinationCollection = collectionFilter
        if let loadingTask { await loadingTask.value }
        let result = await Task.detached(priority: .userInitiated) {
            readImportBatch(urls: urls, section: destination)
        }.value

        for var imported in result.documents {
            if let destinationCollection { imported.collection = destinationCollection }
            documents.append(imported)
            revisions[imported.id] = 1
            dirtyIDs.insert(imported.id)
        }
        if let last = result.documents.last {
            selectedSection = destination
            collectionFilter = destinationCollection
            query = ""
            selectedDocumentID = last.id
            refreshSaveStatus()
            await flush()
        }
        if !result.warnings.isEmpty {
            report("Some files could not be imported:\n" + result.warnings.joined(separator: "\n"))
        }
    }

    func markdownData(for id: UUID) -> Data? {
        guard let document = document(id: id) else { return nil }
        return MarkdownCodec.exportMarkdown(document)
    }

    /// Flush waits for initial loading, Trash operations and every eligible
    /// revision. A failed revision stays dirty, and is attempted at most once
    /// per flush rather than creating an endless retry loop on a full disk.
    func flush() async {
        debounceTask?.cancel()
        debounceTask = nil
        if let loadingTask { await loadingTask.value }
        failedRevisions.removeAll()
        while true {
            let deletions = Array(trashTasks.values)
            for task in deletions { await task.value }
            if let writer = ensureWriter() { await writer.value }
            if trashTasks.isEmpty && !hasEligibleWrites && writerTask == nil { break }
        }
        debounceTask?.cancel()
        debounceTask = nil
        refreshSaveStatus()
    }

    func retrySave() async {
        errorMessage = nil
        if let loadingTask { await loadingTask.value }
        if loadFailed {
            beginLoading()
            if let loadingTask { await loadingTask.value }
        }
        await flush()
    }

    private func beginLoading() {
        guard loadingTask == nil else { return }
        isLoading = true
        refreshSaveStatus()
        loadingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let result = try await self.repository.load()
                // Creating and typing are allowed while loading. Existing
                // memory wins; a late disk snapshot never replaces those edits.
                let memoryIDs = Set(self.documents.map(\.id))
                let untouched = result.documents.filter {
                    !memoryIDs.contains($0.id)
                        && !self.deletedIDs.contains($0.id)
                        && !self.pendingTrashIDs.contains($0.id)
                }
                self.documents.append(contentsOf: untouched)
                for document in untouched { self.revisions[document.id] = 0 }
                self.loadFailed = false
                if !result.warnings.isEmpty {
                    self.report("Some library files could not be opened. Their originals are untouched:\n" + result.warnings.joined(separator: "\n"))
                }
                if self.selectedDocumentID == nil {
                    self.selectedDocumentID = self.visibleDocuments.first?.id
                }
            } catch {
                self.loadFailed = true
                self.report("Couldn’t open the Clay library. \(error.localizedDescription)")
            }
            self.isLoading = false
            self.loadingTask = nil
            self.refreshSaveStatus()
            if self.hasEligibleWrites { self.scheduleSave() }
        }
    }

    private func edit(id: UUID, change: (inout WritingDocument) -> Void) {
        guard !pendingTrashIDs.contains(id),
              let index = documents.firstIndex(where: { $0.id == id }) else { return }
        var value = documents[index]
        change(&value)
        guard value != documents[index] else { return }
        value.updatedAt = Date()
        documents[index] = value
        revisions[id, default: 0] &+= 1
        dirtyIDs.insert(id)
        failedRevisions[id] = nil
        scheduleSave()
    }

    private func scheduleSave() {
        debounceTask?.cancel()
        refreshSaveStatus()
        debounceTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 500_000_000) }
            catch { return }
            guard !Task.isCancelled, let self else { return }
            if let loadingTask = self.loadingTask { await loadingTask.value }
            guard !Task.isCancelled else { return }
            if let writer = self.ensureWriter() { await writer.value }
        }
    }

    private var hasEligibleWrites: Bool {
        dirtyIDs.contains { id in
            !pendingTrashIDs.contains(id)
                && !deletedIDs.contains(id)
                && failedRevisions[id] != revisions[id, default: 0]
                && document(id: id) != nil
        }
    }

    private func ensureWriter() -> Task<Void, Never>? {
        if let writerTask { return writerTask }
        guard !isLoading, hasEligibleWrites else { return nil }
        let token = UUID()
        writerToken = token
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.writePendingDocuments()
            if self.writerToken == token {
                self.writerTask = nil
                self.writerToken = nil
                self.refreshSaveStatus()
            }
        }
        writerTask = task
        refreshSaveStatus()
        return task
    }

    private func writePendingDocuments() async {
        while hasEligibleWrites {
            // Use deterministic order. A document can be edited while another
            // save is awaiting disk; take its latest snapshot just before send.
            let ids = dirtyIDs.sorted { $0.uuidString < $1.uuidString }
            for id in ids {
                guard dirtyIDs.contains(id), !pendingTrashIDs.contains(id),
                      !deletedIDs.contains(id),
                      failedRevisions[id] != revisions[id, default: 0],
                      let snapshot = document(id: id) else { continue }
                let sentRevision = revisions[id, default: 0]
                do {
                    try await repository.save(snapshot)
                    if revisions[id] == sentRevision && !pendingTrashIDs.contains(id) {
                        dirtyIDs.remove(id)
                        failedRevisions[id] = nil
                    }
                } catch {
                    guard !pendingTrashIDs.contains(id), !deletedIDs.contains(id) else { continue }
                    // If more typing happened during I/O, that newer revision
                    // remains eligible. Never mark it saved from an older write.
                    failedRevisions[id] = sentRevision
                    report("Couldn’t save “\(snapshot.displayTitle)”. Your latest changes remain in this window. \(error.localizedDescription)")
                }
                refreshSaveStatus()
            }
        }
    }

    private func refreshSaveStatus() {
        if loadFailed || !failedRevisions.isEmpty {
            saveStatus = "Save failed"
        } else if isLoading {
            saveStatus = "Loading…"
        } else if !dirtyIDs.isEmpty || !pendingTrashIDs.isEmpty || writerTask != nil {
            saveStatus = "Saving…"
        } else {
            saveStatus = "Saved"
        }
    }

    private func report(_ message: String) {
        if let existing = errorMessage, !existing.isEmpty {
            if !existing.contains(message) { errorMessage = existing + "\n\n" + message }
        } else {
            errorMessage = message
        }
    }

    private static func documentOrder(_ lhs: WritingDocument, _ rhs: WritingDocument) -> Bool {
        if lhs.pinned != rhs.pinned { return lhs.pinned }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

private struct ImportBatch: Sendable {
    var documents: [WritingDocument] = []
    var warnings: [String] = []
}

/// Kept outside ClayStore so its synchronous file reads do not inherit the
/// main actor. Imported source files are only read, never moved or modified.
private func readImportBatch(urls: [URL], section: WritingSection) -> ImportBatch {
    var result = ImportBatch()
    let maximumBytes = 10 * 1_024 * 1_024
    for url in urls {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else {
                throw NSError(domain: "Clay.Import", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Choose a Markdown or plain text file."
                ])
            }
            guard (values.fileSize ?? 0) <= maximumBytes else {
                throw NSError(domain: "Clay.Import", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "This file is larger than the 10 MB import limit."
                ])
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= maximumBytes else {
                throw NSError(domain: "Clay.Import", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "This file is larger than the 10 MB import limit."
                ])
            }
            result.documents.append(try MarkdownCodec.importMarkdown(
                data, filename: url.lastPathComponent, section: section
            ))
        } catch {
            result.warnings.append("\(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
    return result
}
