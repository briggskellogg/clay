import Foundation
import Combine
import ClayCore
import Darwin

/// Access to one explicitly selected private folder. The local library remains
/// usable while its provider is offline; this class never infers remote deletes.
@MainActor
final class ClaySyncFolder: ObservableObject {
    @Published private(set) var folderName: String?
    @Published private(set) var status = "Not connected"
    @Published private(set) var detail = "Choose the same private folder on each device."

    var isConnected: Bool { folderName != nil }
    var onChange: (@MainActor () -> Void)?

    private static let bookmarkKey = "clay.privateLibraryBookmark"
    private static let deviceKey = "clay.privateLibraryDeviceID"
    private let defaults: UserDefaults
    private let worker: ClaySyncFolderWorker
    private var connectionID = UUID()
    private var changeTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedID = defaults.string(forKey: Self.deviceKey).flatMap(UUID.init(uuidString:))
        let deviceID = savedID ?? UUID()
        defaults.set(deviceID.uuidString.lowercased(), forKey: Self.deviceKey)
        worker = ClaySyncFolderWorker(deviceID: deviceID)
        if let bookmark = defaults.data(forKey: Self.bookmarkKey) {
            let identifier = connectionID
            status = "Connecting…"
            Task { [weak self] in
                guard let self, self.connectionID == identifier else { return }
                do {
                    let info = try await self.worker.restore(bookmark, identifier: identifier,
                                                            changed: self.changeHandler(identifier))
                    guard self.connectionID == identifier else { return }
                    self.didConnect(info)
                    self.onChange?()
                } catch {
                    guard self.connectionID == identifier else { return }
                    self.status = "Reconnect folder"
                    self.detail = error.localizedDescription
                }
            }
        }
    }

    func connect(to url: URL) async throws {
        let identifier = UUID()
        connectionID = identifier
        changeTask?.cancel()
        folderName = nil
        status = "Connecting…"
        detail = "Checking the selected folder."
        do {
            let info = try await worker.connect(url, identifier: identifier, changed: changeHandler(identifier))
            guard connectionID == identifier else { throw CancellationError() }
            didConnect(info)
        } catch {
            if connectionID == identifier {
                status = "Folder unavailable"
                detail = error.localizedDescription
            }
            throw error
        }
    }

    func disconnect() {
        connectionID = UUID()
        changeTask?.cancel()
        defaults.removeObject(forKey: Self.bookmarkKey)
        worker.disconnect()
        folderName = nil
        status = "Not connected"
        detail = "Your local writing and the private folder are kept."
    }

    /// Call with empty arrays before importing remote records into the local
    /// engine. A subsequent exchange publishes that engine's immutable records.
    /// The returned records were read before any write in this exchange.
    func exchange(records: [LibrarySyncRecordFile], snapshot: [WritingDocument]) async throws -> [Data] {
        guard isConnected else { throw ClaySyncFolderError.disconnected }
        let identifier = connectionID
        status = "Checking private folder…"
        detail = "Your cloud provider handles transfers between devices."
        do {
            let result = try await worker.exchange(records: records, snapshot: snapshot, identifier: identifier)
            guard connectionID == identifier else { throw CancellationError() }
            status = "Private folder updated"
            detail = "Available changes checked. Cloud transfers may still be pending."
            return result
        } catch {
            if connectionID == identifier {
                status = "Sync needs attention"
                detail = error.localizedDescription
            }
            throw error
        }
    }

    private func didConnect(_ info: ClaySyncFolderConnectionInfo) {
        defaults.set(info.bookmark, forKey: Self.bookmarkKey)
        folderName = info.name
        status = "Private folder connected"
        detail = "Your cloud provider handles transfers between devices."
    }

    private func changeHandler(_ identifier: UUID) -> @Sendable () -> Void {
        { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.connectionID == identifier, self.isConnected else { return }
                self.changeTask?.cancel()
                self.changeTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard !Task.isCancelled, let self, self.connectionID == identifier else { return }
                    self.onChange?()
                }
            }
        }
    }
}

private struct ClaySyncFolderConnectionInfo: Sendable {
    let name: String
    let bookmark: Data
}

private enum ClaySyncFolderError: Error, LocalizedError {
    case disconnected, unsafeFolder, outsideFolder, sourceFolder, unknownFormat, invalidRecords, recordCollision, unavailable

    var errorDescription: String? {
        switch self {
        case .disconnected: return "Connect a private folder before syncing."
        case .unsafeFolder: return "Choose a regular private folder. Clay does not follow symbolic links inside its sync folder."
        case .outsideFolder: return "The file provider returned a location outside the selected private folder. Choose the folder again."
        case .sourceFolder: return "Choose a private writing folder outside Git repositories and [projects]."
        case .unknownFormat: return "This folder contains an unknown or incomplete Clay sync format. Its files were left untouched."
        case .invalidRecords: return "The private folder contains an unrecognized record. Its files were left untouched."
        case .recordCollision: return "Two different sync records have the same name. Clay kept the existing record and stopped this exchange."
        case .unavailable: return "The private folder is unavailable or still downloading. Local writing is kept; try again when the folder is available."
        }
    }
}

/// All access and file coordination run on this queue, including potentially
/// blocking provider downloads. Scoped access remains alive with the presenter.
private final class ClaySyncFolderWorker: @unchecked Sendable {
    private struct Connection {
        let id: UUID
        let url: URL
        let accessStarted: Bool
        let presenter: ClaySyncFolderPresenter
    }

    private struct Format: Codable, Equatable {
        let format: String
        let version: Int
        static let current = Format(format: "clay-private-library", version: 1)
    }

    private struct ExportManifest: Encodable {
        struct Entry: Encodable {
            let id: UUID
            let title: String
            let section: WritingSection
            let collection: String
            let file: String
        }
        let format = "clay-readable-export"
        let version = 1
        let authoritative = false
        let note = "Derived reading copies. Changes here do not import into Clay. Only files listed in this manifest belong to the current snapshot."
        let deviceID: UUID
        let documents: [Entry]
    }

    private let queue = DispatchQueue(label: "com.briggskellogg.clay.private-folder", qos: .utility)
    private let fileManager = FileManager.default
    private let deviceID: UUID
    private var connection: Connection?

    init(deviceID: UUID) { self.deviceID = deviceID }

    deinit {
        if let connection {
            NSFileCoordinator.removeFilePresenter(connection.presenter)
            if connection.accessStarted { connection.url.stopAccessingSecurityScopedResource() }
        }
    }

    func connect(_ url: URL, identifier: UUID, changed: @escaping @Sendable () -> Void) async throws -> ClaySyncFolderConnectionInfo {
        try await perform { try self.open(url, identifier: identifier, changed: changed) }
    }

    func restore(_ bookmark: Data, identifier: UUID, changed: @escaping @Sendable () -> Void) async throws -> ClaySyncFolderConnectionInfo {
        try await perform {
            var stale = false
            #if os(macOS)
            let url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI], bookmarkDataIsStale: &stale)
            #else
            let url = try URL(resolvingBookmarkData: bookmark, options: [.withoutUI], bookmarkDataIsStale: &stale)
            #endif
            // Successfully resolved stale bookmarks can be renewed while their
            // permission is still valid; open() verifies access before saving.
            return try self.open(url, identifier: identifier, changed: changed)
        }
    }

    func disconnect() { queue.async { self.close() } }

    func exchange(records: [LibrarySyncRecordFile], snapshot: [WritingDocument], identifier: UUID) async throws -> [Data] {
        try await perform {
            guard let connection = self.connection, connection.id == identifier else { throw ClaySyncFolderError.disconnected }
            let root = connection.url
            try self.rejectSourceFolder(root)
            let sync = root.appendingPathComponent("ClaySync", isDirectory: true)
            try self.verifyFormat(root: root, sync: sync)
            let directory = sync.appendingPathComponent("Records", isDirectory: true)
            let names: [String] = try self.coordinate(directory, writing: false) { url in
                try self.requireDirectory(url, root: root)
                return try self.fileManager.contentsOfDirectory(atPath: url.path)
            }
            var remote: [String: Data] = [:]
            for name in names.sorted() where name != ".DS_Store" {
                let canonical = self.canonicalRecordName(name)
                guard let canonical else { throw ClaySyncFolderError.invalidRecords }
                let url = directory.appendingPathComponent(canonical)
                let data = try self.read(url, root: root)
                if let previous = remote[canonical], previous != data { throw ClaySyncFolderError.recordCollision }
                remote[canonical] = data
            }
            // No writes happen until every discoverable remote record is read.
            // Corrupt record payloads remain available to the core quarantine.
            let result = remote.keys.sorted().compactMap { remote[$0] }
            for record in records {
                guard self.canonicalRecordName(record.name) == record.name else { throw ClaySyncFolderError.invalidRecords }
                if let previous = remote[record.name], previous != record.data { throw ClaySyncFolderError.recordCollision }
            }
            for record in records {
                if remote[record.name] == record.data { continue }
                try self.write(record.data, to: directory.appendingPathComponent(record.name), root: root, immutable: true)
            }
            if !records.isEmpty || !snapshot.isEmpty {
                try self.export(snapshot, root: root, sync: sync)
            }
            return result
        }
    }

    private func perform<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { continuation.resume(with: Result { try operation() }) }
        }
    }

    private func open(_ url: URL, identifier: UUID, changed: @escaping @Sendable () -> Void) throws -> ClaySyncFolderConnectionInfo {
        close()
        guard url.isFileURL else { throw ClaySyncFolderError.unsafeFolder }
        let started = url.startAccessingSecurityScopedResource()
        do {
            try rejectSourceFolder(url)
            try requireDirectory(url, root: url)
            let sync = url.appendingPathComponent("ClaySync", isDirectory: true)
            try coordinate(url, writing: true) { selected in
                try self.requireDirectory(selected, root: url)
                try self.ensureDirectory(sync, root: url)
            }
            let marker = sync.appendingPathComponent("format.json")
            let existing = try coordinate(sync, writing: false) { directory in
                try self.requireDirectory(directory, root: url)
                return try self.fileManager.contentsOfDirectory(atPath: directory.path)
            }
            if !existing.contains("format.json") && !existing.contains(".format.json.icloud") {
                guard existing.isEmpty || existing == [".DS_Store"] else { throw ClaySyncFolderError.unknownFormat }
                try write(try encoded(Format.current), to: marker, root: url, immutable: true)
            }
            try verifyFormat(root: url, sync: sync)
            try coordinate(sync, writing: true) { directory in
                try self.requireDirectory(directory, root: url)
                try self.ensureDirectory(directory.appendingPathComponent("Records", isDirectory: true), root: url)
                try self.ensureDirectory(directory.appendingPathComponent("Exports", isDirectory: true), root: url)
            }
            #if os(macOS)
            let bookmark = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            #else
            let bookmark = try url.bookmarkData(options: [.minimalBookmark], includingResourceValuesForKeys: nil, relativeTo: nil)
            #endif
            let presenter = ClaySyncFolderPresenter(url: url, changed: changed)
            connection = Connection(id: identifier, url: url, accessStarted: started, presenter: presenter)
            NSFileCoordinator.addFilePresenter(presenter)
            return ClaySyncFolderConnectionInfo(name: url.lastPathComponent, bookmark: bookmark)
        } catch {
            if started { url.stopAccessingSecurityScopedResource() }
            throw error
        }
    }

    private func close() {
        if let connection {
            NSFileCoordinator.removeFilePresenter(connection.presenter)
            if connection.accessStarted { connection.url.stopAccessingSecurityScopedResource() }
        }
        connection = nil
    }

    private func rejectSourceFolder(_ url: URL) throws {
        // Check the resolved location too, so a parent alias cannot lead into a
        // source mirror. Keep using the original security-scoped URL for I/O.
        for location in [url.standardizedFileURL, url.resolvingSymlinksInPath()] {
            let parts = location.pathComponents.map { $0.lowercased() }
            guard !parts.contains(".git"), !parts.contains("[projects]"), location.path != "/" else {
                throw ClaySyncFolderError.sourceFolder
            }
            // Fixed ancestor probes only: never enumerate unrelated folders.
            var ancestor = location
            while ancestor.path != "/" {
                if fileManager.fileExists(atPath: ancestor.appendingPathComponent(".git").path)
                    || fileManager.fileExists(atPath: ancestor.appendingPathComponent(".clay-sync-manifest.json").path) {
                    throw ClaySyncFolderError.sourceFolder
                }
                ancestor.deleteLastPathComponent()
            }
        }
    }

    private func verifyFormat(root: URL, sync: URL) throws {
        let data = try read(sync.appendingPathComponent("format.json"), root: root)
        guard let format = try? JSONDecoder().decode(Format.self, from: data), format == .current else {
            throw ClaySyncFolderError.unknownFormat
        }
    }

    private func canonicalRecordName(_ name: String) -> String? {
        let candidate: String
        if name.hasPrefix("."), name.hasSuffix(".icloud") {
            candidate = String(name.dropFirst().dropLast(".icloud".count))
        } else { candidate = name }
        guard candidate.hasSuffix(".json"),
              let id = UUID(uuidString: String(candidate.dropLast(5))),
              candidate == id.uuidString.lowercased() + ".json" else { return nil }
        return candidate
    }

    private func read(_ url: URL, root: URL) throws -> Data {
        try validateAncestors(url, root: root)
        let placeholder = url.deletingLastPathComponent().appendingPathComponent("." + url.lastPathComponent + ".icloud")
        if fileManager.fileExists(atPath: placeholder.path) {
            try validateAncestors(placeholder, root: root)
            try fileManager.startDownloadingUbiquitousItem(at: url)
        }
        return try coordinate(url, writing: false) { coordinated in
            try self.requireRegularFile(coordinated, root: root)
            return try Data(contentsOf: coordinated)
        }
    }

    private func write(_ data: Data, to url: URL, root: URL, immutable: Bool) throws {
        // Even a coordinated write with no byte changes can notify presenters.
        // Compare through a read first, then recheck inside the write operation.
        try validateAncestors(url, root: root)
        if try itemType(url) != nil {
            let previous = try read(url, root: root)
            if previous == data { return }
            if immutable { throw ClaySyncFolderError.recordCollision }
        }
        try coordinate(url, writing: true) { coordinated in
            try self.validateAncestors(coordinated, root: root)
            if try self.itemType(coordinated) != nil {
                try self.requireRegularFile(coordinated, root: root)
                let previous = try Data(contentsOf: coordinated)
                if previous == data { return }
                guard !immutable else { throw ClaySyncFolderError.recordCollision }
                try data.write(to: coordinated, options: .atomic)
            } else {
                // Never replace another writer's immutable record, including a
                // record that appeared after the initial directory enumeration.
                try self.createExclusive(data, at: coordinated, root: root)
            }
        }
    }

    private func createExclusive(_ data: Data, at url: URL, root: URL) throws {
        // Foundation forbids combining .atomic and .withoutOverwriting. Stage
        // complete bytes on the same volume, then use an exclusive atomic rename.
        // Staging is outside Records so interrupted writes never become records.
        let staging = root.appendingPathComponent("ClaySync", isDirectory: true)
            .appendingPathComponent("Staging", isDirectory: true)
        try ensureDirectory(staging, root: root)
        let temporary = staging.appendingPathComponent(UUID().uuidString.lowercased() + ".tmp")
        try data.write(to: temporary, options: .withoutOverwriting)
        defer { try? fileManager.removeItem(at: temporary) }
        try validateAncestors(url, root: root)
        let result = temporary.withUnsafeFileSystemRepresentation { source in
            url.withUnsafeFileSystemRepresentation { destination in
                renamex_np(source!, destination!, UInt32(RENAME_EXCL))
            }
        }
        if result != 0 {
            let code = errno
            if code == EEXIST {
                try requireRegularFile(url, root: root)
                if try Data(contentsOf: url) == data { return }
                throw ClaySyncFolderError.recordCollision
            }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(code))
        }
    }

    private func export(_ snapshot: [WritingDocument], root: URL, sync: URL) throws {
        let exports = sync.appendingPathComponent("Exports", isDirectory: true)
        let own = exports.appendingPathComponent(deviceID.uuidString.lowercased(), isDirectory: true)
        try validateAncestors(own, root: root)
        if try itemType(own) == nil {
            try coordinate(exports, writing: true) { directory in
                try self.requireDirectory(directory, root: root)
                try self.ensureDirectory(own, root: root)
            }
        } else {
            try requireDirectory(own, root: root)
        }
        var entries: [ExportManifest.Entry] = []
        for document in snapshot.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            let name = document.id.uuidString.lowercased() + ".md"
            try write(MarkdownCodec.exportMarkdown(document), to: own.appendingPathComponent(name), root: root, immutable: false)
            entries.append(.init(id: document.id, title: document.displayTitle, section: document.section,
                                 collection: document.collection, file: name))
        }
        // A stable manifest prevents self-triggered sync loops. Obsolete export
        // files are preserved but no longer listed; another device is untouched.
        try write(try encoded(ExportManifest(deviceID: deviceID, documents: entries)),
                  to: own.appendingPathComponent("manifest.json"), root: root, immutable: false)
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(value)
    }

    private func itemType(_ url: URL) throws -> FileAttributeType? {
        do { return try fileManager.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType }
        catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile { return nil }
    }

    private func validateAncestors(_ url: URL, root: URL) throws {
        guard url.isFileURL, root.isFileURL else { throw ClaySyncFolderError.unsafeFolder }
        // A coordinator may return the same folder through a resolved ancestor
        // path, while the picker/bookmark retains the original spelling. Resolve
        // only for identity/containment comparisons; keep the scoped URLs for I/O.
        // Check the selected leaf first so canonicalization cannot hide a link.
        guard try itemType(root) != .typeSymbolicLink else { throw ClaySyncFolderError.unsafeFolder }
        let rootComponents = root.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        // Inspect the original path, not its resolved replacement: even a link
        // targeting another directory *inside* the root must remain forbidden.
        // Finding the selected root in this ancestor chain proves containment.
        // Resolve existing ancestors only: Foundation can normalize /private
        // differently when the final file has not been created yet.
        var current = url
        for _ in 0...url.pathComponents.count {
            let type = try itemType(current)
            if type == .typeSymbolicLink { throw ClaySyncFolderError.unsafeFolder }
            if type != nil,
               current.resolvingSymlinksInPath().standardizedFileURL.pathComponents == rootComponents { return }
            let parent = current.deletingLastPathComponent()
            guard parent.path != current.path else { break }
            current = parent
        }
        throw ClaySyncFolderError.outsideFolder
    }

    private func requireDirectory(_ url: URL, root: URL) throws {
        try validateAncestors(url, root: root)
        guard try itemType(url) == .typeDirectory else { throw ClaySyncFolderError.unavailable }
    }

    private func ensureDirectory(_ url: URL, root: URL) throws {
        try validateAncestors(url, root: root)
        if try itemType(url) == nil { try fileManager.createDirectory(at: url, withIntermediateDirectories: false) }
        try requireDirectory(url, root: root)
    }

    private func requireRegularFile(_ url: URL, root: URL) throws {
        try validateAncestors(url, root: root)
        guard try itemType(url) == .typeRegular else { throw ClaySyncFolderError.unavailable }
    }

    private func coordinate<T>(_ url: URL, writing: Bool, _ body: (URL) throws -> T) throws -> T {
        let coordinator = NSFileCoordinator(filePresenter: connection?.presenter)
        var error: NSError?
        var result: Result<T, Error>?
        let access: (URL) -> Void = { coordinated in result = Result { try body(coordinated) } }
        if writing {
            coordinator.coordinate(writingItemAt: url, options: .forMerging, error: &error, byAccessor: access)
        } else {
            coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &error, byAccessor: access)
        }
        if let error { throw error }
        guard let result else { throw ClaySyncFolderError.unavailable }
        return try result.get()
    }
}

private final class ClaySyncFolderPresenter: NSObject, NSFilePresenter, @unchecked Sendable {
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue
    private let changed: @Sendable () -> Void

    init(url: URL, changed: @escaping @Sendable () -> Void) {
        presentedItemURL = url
        self.changed = changed
        let queue = OperationQueue()
        queue.name = "com.briggskellogg.clay.private-folder-presenter"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        presentedItemOperationQueue = queue
        super.init()
    }

    func presentedItemDidChange() { changed() }
    func presentedItemDidMove(to newURL: URL) { changed() }
    func presentedSubitemDidAppear(at url: URL) { changed() }
    func presentedSubitemDidChange(at url: URL) { changed() }
    func presentedSubitem(at oldURL: URL, didMoveTo newURL: URL) { changed() }
    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        changed()
        completionHandler(nil)
    }
    func accommodatePresentedSubitemDeletion(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        changed()
        completionHandler(nil)
    }
}
