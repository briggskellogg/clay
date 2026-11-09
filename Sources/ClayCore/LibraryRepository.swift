import Foundation

public struct LibraryLoadResult: Sendable {
    public var documents: [WritingDocument]
    public var warnings: [String]

    public init(documents: [WritingDocument], warnings: [String]) {
        self.documents = documents
        self.warnings = warnings
    }
}

public enum LibraryRepositoryError: Error, LocalizedError, Sendable {
    case unsafeLocation(String)
    case identifierMismatch(String)
    case trashedDocument
    case cannotReplaceDamagedFile(String)

    public var errorDescription: String? {
        switch self {
        case .unsafeLocation(let name):
            return "\(name) is not the expected regular file or folder. Clay will not write through a symbolic link."
        case .identifierMismatch(let name):
            return "\(name) has a document identity that does not match its filename. It has been left untouched."
        case .trashedDocument:
            return "This document is already in Trash. A queued save was stopped."
        case .cannotReplaceDamagedFile(let name):
            return "\(name) could not be safely read. Clay has kept the original file and has not overwritten it."
        }
    }
}

/// Serializes local file operations. Each document is one atomic UTF-8 file;
/// changing section or collection never changes its UUID or filename.
public actor LibraryRepository {
    public let rootURL: URL
    private let fileManager = FileManager.default
    private var trashedIDs = Set<UUID>()

    public init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
    }

    public func load() throws -> LibraryLoadResult {
        try prepareDirectories()
        let entries = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension.lowercased() == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var documents: [WritingDocument] = []
        var warnings: [String] = []
        var seen = Set<UUID>()
        for url in entries {
            do {
                try requireRegularFile(url)
                let document = try MarkdownCodec.decode(Data(contentsOf: url))
                guard url.lastPathComponent == filename(for: document.id), seen.insert(document.id).inserted else {
                    throw LibraryRepositoryError.identifierMismatch(url.lastPathComponent)
                }
                documents.append(document)
            } catch {
                warnings.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        documents.sort {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        return LibraryLoadResult(documents: documents, warnings: warnings)
    }

    public func save(_ document: WritingDocument) throws {
        guard !trashedIDs.contains(document.id) else { throw LibraryRepositoryError.trashedDocument }
        try prepareDirectories()
        let destination = rootURL.appendingPathComponent(filename(for: document.id))
        let newContents = try MarkdownCodec.encode(document)
        if fileManager.fileExists(atPath: destination.path) {
            try requireRegularFile(destination)
            let previous = try Data(contentsOf: destination)
            let existing: WritingDocument
            do {
                existing = try MarkdownCodec.decode(previous)
            } catch {
                throw LibraryRepositoryError.cannotReplaceDamagedFile(destination.lastPathComponent)
            }
            guard existing.id == document.id else {
                throw LibraryRepositoryError.identifierMismatch(destination.lastPathComponent)
            }
            if previous == newContents { return }
            let backup = backupsURL.appendingPathComponent(filename(for: document.id))
            if fileManager.fileExists(atPath: backup.path) { try requireRegularFile(backup) }
            // A failed backup aborts the save. The original remains authoritative.
            try previous.write(to: backup, options: .atomic)
        }
        // Data.write(.atomic) writes a temporary sibling then replaces the file.
        // Metadata and body cannot be committed as different revisions.
        try newContents.write(to: destination, options: .atomic)
    }

    public func trash(_ document: WritingDocument) throws {
        if trashedIDs.contains(document.id) { return }
        // Capture the latest in-memory edit before moving, including a document
        // deleted during its first debounce interval. A failed save stops Trash.
        try save(document)
        let original = rootURL.appendingPathComponent(filename(for: document.id))
        try requireRegularFile(original)
        let archiveName = "\(document.id.uuidString.lowercased())-\(UUID().uuidString.lowercased()).md"
        let destination = trashURL.appendingPathComponent(archiveName)
        try fileManager.moveItem(at: original, to: destination)
        // A canceled autosave may already be queued on this actor. This guard
        // prevents it from recreating the file after the move has completed.
        trashedIDs.insert(document.id)
    }

    private var backupsURL: URL { rootURL.appendingPathComponent("Backups", isDirectory: true) }
    private var trashURL: URL { rootURL.appendingPathComponent("Trash", isDirectory: true) }

    private func filename(for id: UUID) -> String { id.uuidString.lowercased() + ".md" }

    private func prepareDirectories() throws {
        try requireDirectory(rootURL)
        try requireDirectory(backupsURL)
        try requireDirectory(trashURL)
    }

    private func requireDirectory(_ url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw LibraryRepositoryError.unsafeLocation(url.lastPathComponent)
        }
    }

    private func requireRegularFile(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw LibraryRepositoryError.unsafeLocation(url.lastPathComponent)
        }
    }
}
