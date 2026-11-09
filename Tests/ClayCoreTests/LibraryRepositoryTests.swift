import Foundation
import XCTest
@testable import ClayCore

final class LibraryRepositoryTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClayTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root, FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
    }

    func testNewLibraryIsEmptyAndDoesNotSeedWriting() async throws {
        let result = try await LibraryRepository(rootURL: root).load()
        XCTAssertTrue(result.documents.isEmpty)
        XCTAssertTrue(result.warnings.isEmpty)
        XCTAssertTrue(try activeMarkdownFiles().isEmpty)
    }

    func testSaveAndReopenPreservesExactDocument() async throws {
        let document = WritingDocument(title: "A beginning", text: "\n\nFirst line.\r\n\n", collection: "Personal")
        try await LibraryRepository(rootURL: root).save(document)
        let reopened = try await LibraryRepository(rootURL: root).load()
        XCTAssertEqual(reopened.documents, [document])
        XCTAssertTrue(reopened.warnings.isEmpty)
        XCTAssertEqual(try activeMarkdownFiles().map(\.lastPathComponent), [filename(document)])
    }

    func testReplaceKeepsPreviousVersionAndNoOpDoesNotRotateBackup() async throws {
        let repository = LibraryRepository(rootURL: root)
        let original = WritingDocument(title: "Working title", text: "Original body\n")
        try await repository.save(original)
        let originalBytes = try Data(contentsOf: fileURL(original))
        var revised = original
        revised.title = "Final title"
        revised.text = "\nRevised body\n\n"
        revised.updatedAt = original.updatedAt.addingTimeInterval(1)
        try await repository.save(revised)

        let backup = root.appendingPathComponent("Backups").appendingPathComponent(filename(original))
        XCTAssertEqual(try Data(contentsOf: backup), originalBytes)
        XCTAssertEqual(try MarkdownCodec.decode(Data(contentsOf: fileURL(original))), revised)
        try await repository.save(revised)
        XCTAssertEqual(try Data(contentsOf: backup), originalBytes, "A no-op save must preserve the prior revision.")
    }

    func testChangingSectionRetainsIdentityAndOneActiveFile() async throws {
        let repository = LibraryRepository(rootURL: root)
        var document = WritingDocument(title: "Ready", text: "One piece of writing.")
        try await repository.save(document)
        let originalID = document.id
        document.section = .pieces
        document.updatedAt = document.updatedAt.addingTimeInterval(1)
        try await repository.save(document)
        let reopened = try await repository.load()
        XCTAssertEqual(reopened.documents.count, 1)
        XCTAssertEqual(reopened.documents.first?.id, originalID)
        XCTAssertEqual(reopened.documents.first?.section, .pieces)
        XCTAssertEqual(try activeMarkdownFiles().count, 1)
    }

    func testTrashCapturesLatestUnsavedTextAndStopsQueuedResurrection() async throws {
        let repository = LibraryRepository(rootURL: root)
        let original = WritingDocument(title: "A draft", text: "Saved version")
        try await repository.save(original)
        var unsaved = original
        unsaved.text = "The edit made just before deleting.\n\n"
        unsaved.updatedAt = original.updatedAt.addingTimeInterval(1)
        try await repository.trash(unsaved)

        let loaded = try await repository.load()
        XCTAssertTrue(loaded.documents.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL(original).path))
        let trashed = try trashFiles()
        XCTAssertEqual(trashed.count, 1)
        XCTAssertEqual(try MarkdownCodec.decode(Data(contentsOf: XCTUnwrap(trashed.first))), unsaved)
        do {
            try await repository.save(original)
            XCTFail("A queued older save must not resurrect a trashed document.")
        } catch LibraryRepositoryError.trashedDocument {
            // Expected: this actor has a tombstone for the deleted identity.
        }
        XCTAssertTrue(try activeMarkdownFiles().isEmpty)
        try await repository.trash(unsaved)
        XCTAssertEqual(try trashFiles().count, 1, "Repeated Trash is idempotent.")
    }

    func testTrashingNewDocumentDuringDebounceStillPreservesItsWriting() async throws {
        let repository = LibraryRepository(rootURL: root)
        let document = WritingDocument(text: "Never autosaved, but still recoverable.")
        try await repository.trash(document)
        let files = try trashFiles()
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(try MarkdownCodec.decode(Data(contentsOf: XCTUnwrap(files.first))), document)
        XCTAssertTrue(try activeMarkdownFiles().isEmpty)
    }

    func testCorruptFileWarnsWithoutHidingGoodDocumentsOrChangingBytes() async throws {
        let repository = LibraryRepository(rootURL: root)
        let good = WritingDocument(title: "Readable", text: "Keep this too.")
        try await repository.save(good)
        let corruptURL = root.appendingPathComponent("damaged.md")
        let corruptBytes = Data("<!-- clay:v1 not-valid -->\n\nDo not overwrite this text.".utf8)
        try corruptBytes.write(to: corruptURL)
        let result = try await repository.load()
        XCTAssertEqual(result.documents, [good])
        XCTAssertEqual(result.warnings.count, 1)
        XCTAssertTrue(result.warnings[0].contains("damaged.md"))
        XCTAssertEqual(try Data(contentsOf: corruptURL), corruptBytes)
    }

    func testMismatchedFilenameIsReportedAndPreserved() async throws {
        let document = WritingDocument(title: "Wrong name", text: "Still exists.")
        let bytes = try MarkdownCodec.encode(document)
        let misplaced = root.appendingPathComponent("renamed.md")
        try bytes.write(to: misplaced)
        let result = try await LibraryRepository(rootURL: root).load()
        XCTAssertTrue(result.documents.isEmpty)
        XCTAssertEqual(result.warnings.count, 1)
        XCTAssertEqual(try Data(contentsOf: misplaced), bytes)
    }

    func testSaveRefusesToOverwriteCorruptDestination() async throws {
        let document = WritingDocument(title: "Recovery", text: "New content")
        let damaged = Data("These bytes must remain on disk.".utf8)
        try damaged.write(to: fileURL(document))
        do {
            try await LibraryRepository(rootURL: root).save(document)
            XCTFail("The damaged existing file must not be overwritten.")
        } catch LibraryRepositoryError.cannotReplaceDamagedFile(_) {
            // Expected: recovery is an explicit user action, never an autosave.
        }
        XCTAssertEqual(try Data(contentsOf: fileURL(document)), damaged)
    }

    func testSaveRefusesExistingFileWithDifferentIdentity() async throws {
        let intended = WritingDocument(text: "New content")
        let other = WritingDocument(text: "Existing identity")
        let originalBytes = try MarkdownCodec.encode(other)
        try originalBytes.write(to: fileURL(intended))
        do {
            try await LibraryRepository(rootURL: root).save(intended)
            XCTFail("A filename collision must not replace a different identity.")
        } catch LibraryRepositoryError.identifierMismatch(_) {
            // Expected.
        }
        XCTAssertEqual(try Data(contentsOf: fileURL(intended)), originalBytes)
    }

    func testBackupFailureAbortsSaveAndLeavesOriginalIntact() async throws {
        let repository = LibraryRepository(rootURL: root)
        let original = WritingDocument(text: "Original content")
        try await repository.save(original)
        let bytes = try Data(contentsOf: fileURL(original))
        let blockedBackup = root.appendingPathComponent("Backups").appendingPathComponent(filename(original))
        try FileManager.default.createDirectory(at: blockedBackup, withIntermediateDirectories: false)
        var revised = original
        revised.text = "A later version"
        do {
            try await repository.save(revised)
            XCTFail("A failed backup must stop replacement of the active document.")
        } catch {
            XCTAssertEqual(try Data(contentsOf: fileURL(original)), bytes)
        }
    }

    func testFailedTrashKeepsActiveDocument() async throws {
        let repository = LibraryRepository(rootURL: root)
        let original = WritingDocument(text: "Keep me active")
        try await repository.save(original)
        let trash = root.appendingPathComponent("Trash")
        try FileManager.default.removeItem(at: trash)
        try Data("A file cannot serve as the Trash folder.".utf8).write(to: trash)
        do {
            try await repository.trash(original)
            XCTFail("An invalid Trash location must not remove the active document.")
        } catch {
            XCTAssertEqual(try MarkdownCodec.decode(Data(contentsOf: fileURL(original))), original)
        }
    }

    func testSymbolicLinkIsNotFollowedOnLoadOrSave() async throws {
        let document = WritingDocument(text: "Outside content")
        let outside = root.appendingPathComponent("outside.txt")
        let bytes = try MarkdownCodec.encode(document)
        try bytes.write(to: outside)
        do {
            try FileManager.default.createSymbolicLink(at: fileURL(document), withDestinationURL: outside)
        } catch {
            throw XCTSkip("Symbolic links are unavailable in this test environment: \(error)")
        }
        let repository = LibraryRepository(rootURL: root)
        let result = try await repository.load()
        XCTAssertTrue(result.documents.isEmpty)
        XCTAssertEqual(result.warnings.count, 1)
        do {
            try await repository.save(document)
            XCTFail("A symbolic link must not be used as a document destination.")
        } catch LibraryRepositoryError.unsafeLocation(_) {
            // Expected.
        }
        XCTAssertEqual(try Data(contentsOf: outside), bytes)
    }

    private func filename(_ document: WritingDocument) -> String {
        document.id.uuidString.lowercased() + ".md"
    }

    private func fileURL(_ document: WritingDocument) -> URL {
        root.appendingPathComponent(filename(document))
    }

    private func activeMarkdownFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }
    }

    private func trashFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: root.appendingPathComponent("Trash"), includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "md" }
    }
}
