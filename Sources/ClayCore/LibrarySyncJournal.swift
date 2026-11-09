import CryptoKit
import Foundation

public struct LibrarySyncRecordFile: Sendable, Equatable {
    public var name: String
    public var data: Data

    public init(name: String, data: Data) {
        self.name = name
        self.data = data
    }
}

public struct LibrarySyncConflict: Sendable, Equatable {
    public var revisionID: UUID
    public var document: WritingDocument

    public init(revisionID: UUID, document: WritingDocument) {
        self.revisionID = revisionID
        self.document = document
    }
}

public struct LibrarySyncSnapshot: Sendable {
    public var documents: [WritingDocument]
    /// Only heads with the selected, exactly equal content are acknowledged.
    /// Editing it must not resolve a different version never displayed.
    public var parents: [UUID: Set<UUID>]
    public var deletedIDs: Set<UUID>
    public var conflicts: [LibrarySyncConflict]
    public var warnings: [String]

    public init(
        documents: [WritingDocument] = [],
        parents: [UUID: Set<UUID>] = [:],
        deletedIDs: Set<UUID> = [],
        conflicts: [LibrarySyncConflict] = [],
        warnings: [String] = []
    ) {
        self.documents = documents
        self.parents = parents
        self.deletedIDs = deletedIDs
        self.conflicts = conflicts
        self.warnings = warnings
    }
}

public enum LibrarySyncJournalError: Error, LocalizedError, Sendable {
    case unsafeLocation(String)
    case invalidRecord(String)
    case immutableRecordChanged(String)
    case invalidParents

    public var errorDescription: String? {
        switch self {
        case .unsafeLocation(let name):
            return "\(name) is not the expected regular file or folder. Clay will not follow a symbolic link."
        case .invalidRecord(let reason):
            return "A sync record could not be validated: \(reason). Its original has been preserved."
        case .immutableRecordChanged(let name):
            return "\(name) differs from an existing immutable sync record. Neither version has been overwritten."
        case .invalidParents:
            return "The saved version this edit was based on is not available. Your writing has not been replaced."
        }
    }
}

/// A local, append-only journal. Its root belongs in application support, never
/// inside the selected cloud folder. The transport copies records by name; the
/// existing LibraryRepository remains the editable local projection.
///
/// Revision ancestry determines ordering, not device clocks. Every deletion
/// permanently retires its original document identity; concurrent or delayed
/// edits survive as conflicts that can be restored under new identities.
public actor LibrarySyncJournal {
    public let rootURL: URL
    private let fileManager = FileManager.default
    private static let bootstrapDevice = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    private static let bootstrapMarker = Data("Clay sync bootstrap v1\n".utf8)

    public init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
    }

    /// Imports the pre-journal library once without changing any original file.
    /// Stable seed IDs make an interrupted bootstrap safe to repeat. The marker
    /// is published only after every seed is durable, including an empty import.
    public func bootstrap(documents: [WritingDocument]) throws -> LibrarySyncSnapshot {
        try prepareDirectories()
        if try itemExists(markerURL) {
            try requireRegularFile(markerURL)
            guard try Data(contentsOf: markerURL) == Self.bootstrapMarker else {
                throw LibrarySyncJournalError.invalidRecord("bootstrap marker")
            }
            return try snapshot()
        }
        for document in documents.sorted(by: { key($0.id) < key($1.id) }) {
            // The whole document participates in the ID. Distinct legacy
            // versions of the same document become recoverable concurrent roots.
            let encoded = try MarkdownCodec.encode(document)
            let id = stableID(Data("Clay legacy seed v1\n".utf8) + encoded)
            let revision = try Revision(
                id: id, deviceID: Self.bootstrapDevice, parents: [],
                document: document, deleted: false
            )
            try publish(try encodeSyncValue(revision), at: recordURL(id))
        }
        try publish(Self.bootstrapMarker, at: markerURL)
        return try snapshot()
    }

    /// The caller supplies the parents captured when this content was displayed.
    /// Even an edit racing a remote deletion is journaled for later recovery.
    @discardableResult
    public func record(document: WritingDocument, parents: Set<UUID>) throws -> UUID {
        try append(document: document, parents: parents, deleted: false)
    }

    @discardableResult
    public func recordDeletion(document: WritingDocument, parents: Set<UUID>) throws -> UUID {
        try append(document: document, parents: parents, deleted: true)
    }

    /// Malformed or conflicting incoming records are retained in Rejected, and
    /// do not prevent valid records in the same batch from reaching the journal.
    /// Structurally valid records with missing parents remain pending until their
    /// ancestors arrive; they are still exported to help other devices converge.
    public func merge(records: [Data]) throws -> LibrarySyncSnapshot {
        try prepareDirectories()
        var warnings: [String] = []
        for data in records {
            do {
                let revision = try decode(data)
                try publish(data, at: recordURL(revision.payload.id))
            } catch {
                warnings.append(error.localizedDescription)
                // Preserve the exact bytes rather than trying to repair or
                // replace a record in place. Failure to quarantine is reported.
                do {
                    let name = digest(data) + ".record"
                    try publish(data, at: rejectedURL.appendingPathComponent(name))
                } catch {
                    warnings.append("Couldn’t retain a rejected sync record locally: \(error.localizedDescription)")
                }
            }
        }
        var result = try snapshot()
        result.warnings = Array(Set(result.warnings + warnings)).sorted()
        return result
    }

    public func snapshot() throws -> LibrarySyncSnapshot {
        try prepareDirectories()
        let loaded = try readRecords()
        let complete = completeRecords(loaded.revisions)
        var result = LibrarySyncSnapshot(warnings: loaded.warnings + complete.warnings)
        let records = complete.revisions
        let superseded = Set(records.values.flatMap { $0.payload.parents })
        let grouped = Dictionary(grouping: records.values, by: { $0.payload.document.id })
        for documentID in grouped.keys.sorted(by: { key($0) < key($1) }) {
            guard let versions = grouped[documentID] else { continue }
            let deleted = versions.contains { $0.payload.deleted }
            if deleted { result.deletedIDs.insert(documentID) }
            let liveHeads = versions.filter {
                !$0.payload.deleted && !superseded.contains($0.payload.id)
            }.sorted { key($0.payload.id) < key($1.payload.id) }
            // Two devices can independently materialize the same conflict copy.
            // Equal snapshots are one visible version, with all equivalent heads
            // acknowledged. Otherwise those copies would create copies forever.
            let groups = Dictionary(grouping: liveHeads, by: { $0.payload.document })
                .values.map { $0.sorted { key($0.payload.id) < key($1.payload.id) } }
                .sorted {
                    // An edit of the visible head must not randomly switch the
                    // original back to an older conflict because its UUID sorts
                    // differently. Causal depth needs no device-clock agreement.
                    let leftDepth = $0.map { complete.depths[$0.payload.id, default: 0] }.max() ?? 0
                    let rightDepth = $1.map { complete.depths[$0.payload.id, default: 0] }.max() ?? 0
                    if leftDepth != rightDepth { return leftDepth > rightDepth }
                    return key($0[0].payload.id) < key($1[0].payload.id)
                }
            if !deleted, let canonical = groups.first {
                result.documents.append(canonical[0].payload.document)
                result.parents[documentID] = Set(canonical.map { $0.payload.id })
            }
            let conflicts = deleted ? groups[...] : groups.dropFirst()
            result.conflicts.append(contentsOf: conflicts.map {
                LibrarySyncConflict(revisionID: $0[0].payload.id, document: $0[0].payload.document)
            })
        }
        result.conflicts.sort { key($0.revisionID) < key($1.revisionID) }
        result.warnings = Array(Set(result.warnings)).sorted()
        return result
    }

    public func records() throws -> [LibrarySyncRecordFile] {
        try prepareDirectories()
        let loaded = try readRecords()
        return loaded.files.sorted { $0.name < $1.name }
    }

    private var recordsURL: URL { rootURL.appendingPathComponent("Records", isDirectory: true) }
    private var rejectedURL: URL { rootURL.appendingPathComponent("Rejected", isDirectory: true) }
    private var markerURL: URL { rootURL.appendingPathComponent("bootstrap-v1") }
    private var deviceURL: URL { rootURL.appendingPathComponent("device-id") }

    private func append(document: WritingDocument, parents: Set<UUID>, deleted: Bool) throws -> UUID {
        try prepareDirectories()
        let loaded = try readRecords()
        let complete = completeRecords(loaded.revisions).revisions
        for id in parents {
            guard let parent = complete[id], parent.payload.document.id == document.id else {
                throw LibrarySyncJournalError.invalidParents
            }
        }
        if parents.count == 1, let id = parents.first,
           let parent = complete[id], parent.payload.deleted == deleted,
           parent.payload.document == document {
            return id
        }
        let revision = try Revision(
            id: UUID(), deviceID: try deviceID(),
            parents: parents.sorted { key($0) < key($1) },
            document: document, deleted: deleted
        )
        try publish(try encodeSyncValue(revision), at: recordURL(revision.payload.id))
        return revision.payload.id
    }

    private func readRecords() throws -> (
        revisions: [UUID: Revision], files: [LibrarySyncRecordFile], warnings: [String]
    ) {
        let entries = try fileManager.contentsOfDirectory(
            at: recordsURL, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }
        var revisions: [UUID: Revision] = [:]
        var files: [LibrarySyncRecordFile] = []
        var warnings: [String] = []
        for url in entries {
            do {
                try requireRegularFile(url)
                let data = try Data(contentsOf: url)
                let revision = try decode(data)
                guard url.lastPathComponent == filename(revision.payload.id) else {
                    throw LibrarySyncJournalError.invalidRecord("revision filename does not match its identity")
                }
                revisions[revision.payload.id] = revision
                files.append(LibrarySyncRecordFile(name: url.lastPathComponent, data: data))
            } catch {
                warnings.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        let rejected = try fileManager.contentsOfDirectory(at: rejectedURL, includingPropertiesForKeys: nil)
            .filter { !$0.lastPathComponent.hasPrefix(".") }
        if !rejected.isEmpty {
            warnings.append("\(rejected.count) rejected sync record(s) are preserved locally for recovery.")
        }
        return (revisions, files, warnings)
    }

    /// Kahn's algorithm avoids recursive traversal of untrusted/deep graphs.
    /// Cross-document parents, cycles, and missing ancestors cannot become live.
    private func completeRecords(_ revisions: [UUID: Revision]) -> (
        revisions: [UUID: Revision], depths: [UUID: Int], warnings: [String]
    ) {
        var remaining: [UUID: Int] = [:]
        var children: [UUID: [UUID]] = [:]
        var blocked = Set<UUID>()
        for (id, revision) in revisions {
            remaining[id] = revision.payload.parents.count
            for parentID in revision.payload.parents {
                guard let parent = revisions[parentID],
                      parent.payload.document.id == revision.payload.document.id else {
                    blocked.insert(id)
                    continue
                }
                children[parentID, default: []].append(id)
            }
        }
        var ready = remaining.filter { $0.value == 0 && !blocked.contains($0.key) }.map(\.key)
        var cursor = 0
        var complete: [UUID: Revision] = [:]
        var depths: [UUID: Int] = [:]
        while cursor < ready.count {
            let id = ready[cursor]
            cursor += 1
            complete[id] = revisions[id]
            depths[id] = 1 + (revisions[id]?.payload.parents.map { depths[$0, default: 0] }.max() ?? 0)
            for child in children[id, default: []] {
                remaining[child, default: 0] -= 1
                if remaining[child] == 0 && !blocked.contains(child) { ready.append(child) }
            }
        }
        let pending = revisions.count - complete.count
        return (complete, depths, pending == 0 ? [] : [
            "\(pending) sync revision(s) are pending missing or invalid ancestors and have not been applied."
        ])
    }

    private func deviceID() throws -> UUID {
        if !(try itemExists(deviceURL)) {
            let data = Data((UUID().uuidString.lowercased() + "\n").utf8)
            do { try publish(data, at: deviceURL) }
            catch LibrarySyncJournalError.immutableRecordChanged {
                // Another journal instance may have initialized this same root.
                // Use the already-published device identity rather than replace it.
            }
        }
        try requireRegularFile(deviceURL)
        let data = try Data(contentsOf: deviceURL)
        guard let text = String(data: data, encoding: .utf8),
              let id = UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw LibrarySyncJournalError.invalidRecord("device identity")
        }
        return id
    }

    private func prepareDirectories() throws {
        try requireDirectory(rootURL)
        try requireDirectory(recordsURL)
        try requireDirectory(rejectedURL)
    }

    private func itemExists(_ url: URL) throws -> Bool {
        // fileExists alone returns false for a dangling symlink.
        if (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) != nil {
            throw LibrarySyncJournalError.unsafeLocation(url.lastPathComponent)
        }
        return fileManager.fileExists(atPath: url.path)
    }

    private func requireDirectory(_ url: URL) throws {
        if !(try itemExists(url)) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw LibrarySyncJournalError.unsafeLocation(url.lastPathComponent)
        }
    }

    private func requireRegularFile(_ url: URL) throws {
        _ = try itemExists(url)
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw LibrarySyncJournalError.unsafeLocation(url.lastPathComponent)
        }
    }

    /// Publish a fully-written sibling with an exclusive hard link. Unlike
    /// atomic replacement, link creation cannot clobber an existing destination
    /// even if two journal instances race. Temporary files never become records.
    private func publish(_ data: Data, at destination: URL) throws {
        if try itemExists(destination) {
            try requireRegularFile(destination)
            guard try Data(contentsOf: destination) == data else {
                throw LibrarySyncJournalError.immutableRecordChanged(destination.lastPathComponent)
            }
            return
        }
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".pending-\(UUID().uuidString.lowercased())")
        defer { try? fileManager.removeItem(at: temporary) }
        try data.write(to: temporary, options: .withoutOverwriting)
        let handle = try FileHandle(forWritingTo: temporary)
        defer { try? handle.close() }
        try handle.synchronize()
        do {
            try fileManager.linkItem(at: temporary, to: destination)
        } catch {
            guard try itemExists(destination) else { throw error }
            try requireRegularFile(destination)
            guard try Data(contentsOf: destination) == data else {
                throw LibrarySyncJournalError.immutableRecordChanged(destination.lastPathComponent)
            }
        }
    }

    private func filename(_ id: UUID) -> String { key(id) + ".json" }
    private func recordURL(_ id: UUID) -> URL { recordsURL.appendingPathComponent(filename(id)) }
    private func key(_ id: UUID) -> String { id.uuidString.lowercased() }

    private struct Revision: Codable {
        struct Payload: Codable {
            var version: Int
            var id: UUID
            var deviceID: UUID
            var parents: [UUID]
            var document: WritingDocument
            var deleted: Bool
        }
        var payload: Payload
        var checksum: String

        init(id: UUID, deviceID: UUID, parents: [UUID], document: WritingDocument, deleted: Bool) throws {
            _ = try MarkdownCodec.encode(document)
            payload = Payload(version: 1, id: id, deviceID: deviceID, parents: parents, document: document, deleted: deleted)
            checksum = digest(try encodeSyncValue(payload))
        }
    }

    private func decode(_ data: Data) throws -> Revision {
        let revision: Revision
        do { revision = try JSONDecoder().decode(Revision.self, from: data) }
        catch { throw LibrarySyncJournalError.invalidRecord("unreadable JSON") }
        let payload = revision.payload
        guard payload.version == 1 else { throw LibrarySyncJournalError.invalidRecord("unsupported version") }
        guard Set(payload.parents).count == payload.parents.count,
              !payload.parents.contains(payload.id),
              payload.parents == payload.parents.sorted(by: { key($0) < key($1) }) else {
            throw LibrarySyncJournalError.invalidRecord("invalid parent identities")
        }
        _ = try MarkdownCodec.encode(payload.document)
        guard digest(try encodeSyncValue(payload)) == revision.checksum else {
            throw LibrarySyncJournalError.invalidRecord("checksum mismatch")
        }
        return revision
    }
}

private func encodeSyncValue<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(value)
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func stableID(_ data: Data) -> UUID {
    var bytes = Array(SHA256.hash(data: data).prefix(16))
    bytes[6] = (bytes[6] & 0x0f) | 0x50
    bytes[8] = (bytes[8] & 0x3f) | 0x80
    return UUID(uuid: (
        bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
    ))
}
