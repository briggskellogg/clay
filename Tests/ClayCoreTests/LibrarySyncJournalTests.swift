import Foundation
import XCTest
@testable import ClayCore

final class LibrarySyncJournalTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaySyncTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root { try FileManager.default.removeItem(at: root) }
    }

    func testBootstrapIsDeterministicAndOnlyImportsOnceEvenAfterRestart() async throws {
        let original = document("Original\n日本語 🪶\r\n\n")
        let a = journal("a")
        let first = try await a.bootstrap(documents: [original])
        XCTAssertEqual(first.documents, [original])
        let b = journal("b")
        _ = try await b.bootstrap(documents: [original])
        let aFiles = try await a.records()
        let bFiles = try await b.records()
        XCTAssertEqual(aFiles, bFiles, "Identical legacy snapshots need one shared seed identity.")

        let restarted = journal("a")
        let repeated = try await restarted.bootstrap(documents: [original, document("Do not seed later")])
        XCTAssertEqual(repeated.documents, [original])
        let repeatedFiles = try await restarted.records()
        XCTAssertEqual(repeatedFiles, aFiles)
    }

    func testInterruptedBootstrapResumesWithoutDuplicatingCompletedSeeds() async throws {
        let first = document("First", id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let second = document("Second", id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
        let reference = journal("reference")
        _ = try await reference.bootstrap(documents: [second])
        let files = try await reference.records()
        let secondName = try XCTUnwrap(files.first).name
        let interrupted = journal("interrupted")
        _ = try await interrupted.snapshot()
        let obstruction = location("interrupted").appendingPathComponent("Records").appendingPathComponent(secondName)
        try FileManager.default.createDirectory(at: obstruction, withIntermediateDirectories: false)
        do {
            _ = try await interrupted.bootstrap(documents: [first, second])
            XCTFail("Bootstrap should fail while a seed cannot be written.")
        } catch { }
        XCTAssertFalse(FileManager.default.fileExists(atPath: location("interrupted").appendingPathComponent("bootstrap-v1").path))
        let partial = try await interrupted.records()
        XCTAssertEqual(partial.count, 1)
        try FileManager.default.removeItem(at: obstruction)
        let recovered = try await journal("interrupted").bootstrap(documents: [first, second])
        XCTAssertEqual(Set(recovered.documents), [first, second])
        let recoveredFiles = try await interrupted.records()
        XCTAssertEqual(recoveredFiles.count, 2)
    }

    func testEmptyBootstrapDoesNotReimportProjectionOnLaterLaunch() async throws {
        _ = try await journal("a").bootstrap(documents: [])
        let snapshot = try await journal("a").bootstrap(documents: [document("Stale local projection")])
        XCTAssertTrue(snapshot.documents.isEmpty)
    }

    func testChildDeliveredBeforeParentWaitsThenReplacesAncestor() async throws {
        let original = document("Original")
        let a = journal("a")
        let initial = try await a.bootstrap(documents: [original])
        let baseFiles = try await a.records()
        var edited = original
        edited.text = "Later content, with an earlier device clock"
        edited.updatedAt = original.updatedAt.addingTimeInterval(-1_000)
        let child = try await a.record(document: edited, parents: try XCTUnwrap(initial.parents[original.id]))
        let all = try await a.records()
        let childBytes = try XCTUnwrap(all.first { $0.name == filename(child) }).data
        let b = journal("b")
        let pending = try await b.merge(records: [childBytes])
        XCTAssertTrue(pending.documents.isEmpty)
        XCTAssertFalse(pending.warnings.isEmpty)
        let exportedPending = try await b.records()
        XCTAssertEqual(exportedPending.map(\.data), [childBytes], "Pending revisions must survive restarts and be transportable.")
        let completed = try await journal("b").merge(records: baseFiles.map(\.data))
        XCTAssertEqual(completed.documents, [edited])
        XCTAssertEqual(completed.parents[original.id], [child])
        XCTAssertTrue(completed.warnings.isEmpty)
    }

    func testConcurrentOfflineEditsConvergeAndPreserveBothExactBodies() async throws {
        let original = document("Original")
        let a = journal("a")
        let base = try await a.bootstrap(documents: [original])
        let initialRecords = try await a.records()
        let b = journal("b")
        _ = try await b.merge(records: initialRecords.map(\.data))
        let parents = try XCTUnwrap(base.parents[original.id])
        var left = original
        left.text = "  Mac\n\nÉlan 🪶\r\n"
        left.updatedAt = .distantFuture
        var right = original
        right.text = "\nPhone\n日本語\n\n"
        right.updatedAt = .distantPast
        _ = try await a.record(document: left, parents: parents)
        _ = try await b.record(document: right, parents: parents)
        let leftFiles = try await a.records()
        let rightFiles = try await b.records()
        let mergedA = try await a.merge(records: rightFiles.reversed().map(\.data))
        let mergedB = try await b.merge(records: leftFiles.map(\.data))
        XCTAssertEqual(mergedA.documents, mergedB.documents)
        XCTAssertEqual(mergedA.conflicts, mergedB.conflicts)
        XCTAssertEqual(mergedA.parents, mergedB.parents)
        XCTAssertEqual(mergedA.documents.count, 1)
        XCTAssertEqual(mergedA.conflicts.count, 1)
        XCTAssertEqual(Set(mergedA.documents + mergedA.conflicts.map(\.document)), [left, right])
        XCTAssertEqual(mergedA.parents[original.id]?.count, 1, "The editor must not acknowledge an unseen conflicting head.")
        let repeated = try await journal("a").merge(records: leftFiles.map(\.data) + rightFiles.map(\.data))
        XCTAssertEqual(repeated.conflicts, mergedA.conflicts)
        let recordsAfterRepeat = try await a.records()
        XCTAssertEqual(recordsAfterRepeat.count, 3)
    }

    func testEditingCanonicalHeadDoesNotResolveConcurrentConflict() async throws {
        let original = document("Base")
        let a = journal("a")
        let base = try await a.bootstrap(documents: [original])
        var one = original
        one.text = "One"
        var two = original
        two.text = "Two"
        let parents = try XCTUnwrap(base.parents[original.id])
        _ = try await a.record(document: one, parents: parents)
        _ = try await a.record(document: two, parents: parents)
        let split = try await a.snapshot()
        let untouched = try XCTUnwrap(split.conflicts.first)
        var visible = try XCTUnwrap(split.documents.first)
        visible.text += " plus a later edit"
        _ = try await a.record(document: visible, parents: try XCTUnwrap(split.parents[original.id]))
        let after = try await a.snapshot()
        let retained = after.documents + after.conflicts.map(\.document)
        XCTAssertEqual(Set(retained), [visible, untouched.document])
        XCTAssertEqual(after.documents, [visible], "Continuing the visible branch must not randomly revive the older conflict as canonical.")
    }

    func testEquivalentConflictCopiesCoalesceAndTheirNextEditAcknowledgesBothHeads() async throws {
        let copy = document("The same recovered conflict on two devices")
        let a = journal("a")
        let b = journal("b")
        let first = try await a.record(document: copy, parents: [])
        let second = try await b.record(document: copy, parents: [])
        XCTAssertNotEqual(first, second)
        let remote = try await b.records()
        let merged = try await a.merge(records: remote.map(\.data))
        XCTAssertEqual(merged.documents, [copy])
        XCTAssertTrue(merged.conflicts.isEmpty, "Equivalent copies must not recursively produce more conflict copies.")
        XCTAssertEqual(merged.parents[copy.id], [first, second])
        var revised = copy
        revised.text += "\nAn intentional follow-up edit."
        let next = try await a.record(document: revised, parents: try XCTUnwrap(merged.parents[copy.id]))
        let aRecords = try await a.records()
        let final = try await b.merge(records: aRecords.map(\.data))
        XCTAssertEqual(final.documents, [revised])
        XCTAssertEqual(final.parents[copy.id], [next])
        XCTAssertTrue(final.conflicts.isEmpty)
    }

    func testDeletionWinsIdentityAcrossRestartButConcurrentAndDelayedEditsSurvive() async throws {
        let original = document("Base")
        let a = journal("a")
        let initial = try await a.bootstrap(documents: [original])
        let parents = try XCTUnwrap(initial.parents[original.id])
        let seed = try await a.records()
        let b = journal("b")
        _ = try await b.merge(records: seed.map(\.data))
        var unsavedAtDelete = original
        unsavedAtDelete.text = "Latest text captured by Trash"
        _ = try await a.recordDeletion(document: unsavedAtDelete, parents: parents)
        var offline = original
        offline.text = "Offline phone edit"
        let offlineID = try await b.record(document: offline, parents: parents)
        let bFiles = try await b.records()
        let merged = try await a.merge(records: bFiles.map(\.data))
        XCTAssertTrue(merged.documents.isEmpty)
        XCTAssertEqual(merged.deletedIDs, [original.id])
        XCTAssertEqual(merged.conflicts, [LibrarySyncConflict(revisionID: offlineID, document: offline)])
        let restarted = journal("a")
        var delayed = original
        delayed.text = "Typing that finished after the tombstone arrived"
        let delayedID = try await restarted.record(document: delayed, parents: parents)
        let final = try await restarted.snapshot()
        XCTAssertTrue(final.documents.isEmpty)
        XCTAssertEqual(final.deletedIDs, [original.id])
        XCTAssertEqual(Set(final.conflicts.map(\.revisionID)), [offlineID, delayedID])
        XCTAssertEqual(Set(final.conflicts.map(\.document)), [offline, delayed])
        let exported = try await restarted.records()
        XCTAssertTrue(exported.contains { String(decoding: $0.data, as: UTF8.self).contains(unsavedAtDelete.text) })
    }

    func testNoOpSaveReusesItsParentButUnknownOrOtherDocumentParentsAreRejected() async throws {
        let original = document("Base")
        let a = journal("a")
        let initial = try await a.bootstrap(documents: [original])
        let parents = try XCTUnwrap(initial.parents[original.id])
        let reused = try await a.record(document: original, parents: parents)
        XCTAssertEqual(reused, parents.first)
        do {
            _ = try await a.record(document: original, parents: [UUID()])
            XCTFail("Unknown parents must not create an unrooted local edit.")
        } catch LibrarySyncJournalError.invalidParents { }
        do {
            _ = try await a.record(document: document("Other identity"), parents: parents)
            XCTFail("A parent from another document must not suppress it.")
        } catch LibrarySyncJournalError.invalidParents { }
        let files = try await a.records()
        XCTAssertEqual(files.count, 1)
    }

    func testMalformedBatchRetainsValidRecordsAndRejectedBytesAcrossRestart() async throws {
        let original = document("Exact good text")
        let a = journal("a")
        _ = try await a.bootstrap(documents: [original])
        let files = try await a.records()
        let valid = try XCTUnwrap(files.first).data
        let malformed = Data("{broken JSON\nprivate recovery text".utf8)
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: valid) as? [String: Any])
        var body = try XCTUnwrap(payload["payload"] as? [String: Any])
        var documentJSON = try XCTUnwrap(body["document"] as? [String: Any])
        documentJSON["text"] = "Changed without updating the checksum"
        body["document"] = documentJSON
        payload["payload"] = body
        let corrupt = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let b = journal("b")
        let merged = try await b.merge(records: [malformed, valid, corrupt])
        XCTAssertEqual(merged.documents, [original])
        XCTAssertFalse(merged.warnings.isEmpty)
        let rejectedURL = location("b").appendingPathComponent("Rejected")
        let rejected = try FileManager.default.contentsOfDirectory(at: rejectedURL, includingPropertiesForKeys: nil)
        XCTAssertEqual(Set(try rejected.map { try Data(contentsOf: $0) }), [malformed, corrupt])
        let restarted = try await journal("b").snapshot()
        XCTAssertEqual(restarted.documents, [original])
        XCTAssertFalse(restarted.warnings.isEmpty)
    }

    func testDifferingBytesForExistingRevisionNeverReplaceOriginal() async throws {
        let a = journal("a")
        _ = try await a.bootstrap(documents: [document("Original")])
        let files = try await a.records()
        let original = try XCTUnwrap(files.first)
        let altered = original.data + Data("\n".utf8)
        let result = try await a.merge(records: [altered])
        XCTAssertFalse(result.warnings.isEmpty)
        let afterwards = try await a.records()
        XCTAssertEqual(afterwards, [original])
        let rejectedURL = location("a").appendingPathComponent("Rejected")
        let rejected = try FileManager.default.contentsOfDirectory(at: rejectedURL, includingPropertiesForKeys: nil)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(rejected.first)), altered)
    }

    func testSymlinksAreNeverFollowedForJournalRootsOrRecords() async throws {
        let outside = location("outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: location("linked"), withDestinationURL: outside)
        do {
            _ = try await journal("linked").bootstrap(documents: [document("Do not write")])
            XCTFail("A linked journal root must be rejected.")
        } catch LibrarySyncJournalError.unsafeLocation { }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: outside.path).isEmpty)

        let source = journal("source")
        _ = try await source.bootstrap(documents: [document("Source")])
        let files = try await source.records()
        let file = try XCTUnwrap(files.first)
        let destination = journal("destination")
        _ = try await destination.snapshot()
        let outsideFile = outside.appendingPathComponent("keep.json")
        let sentinel = Data("Untouched external content".utf8)
        try sentinel.write(to: outsideFile)
        let linkedRecord = location("destination").appendingPathComponent("Records").appendingPathComponent(file.name)
        try FileManager.default.createSymbolicLink(at: linkedRecord, withDestinationURL: outsideFile)
        let result = try await destination.merge(records: [file.data])
        XCTAssertTrue(result.documents.isEmpty)
        XCTAssertFalse(result.warnings.isEmpty)
        XCTAssertEqual(try Data(contentsOf: outsideFile), sentinel)
    }

    func testConcurrentBootstrapInstancesPublishOneCompleteSeed() async throws {
        let original = document(String(repeating: "Complete Unicode content 🪶\n", count: 1_000))
        let a = journal("shared")
        let b = journal("shared")
        async let first = a.bootstrap(documents: [original])
        async let second = b.bootstrap(documents: [original])
        let results = try await [first, second]
        XCTAssertEqual(results[0].documents, [original])
        XCTAssertEqual(results[1].documents, [original])
        let files = try await a.records()
        XCTAssertEqual(files.count, 1)
    }

    private func location(_ name: String) -> URL { root.appendingPathComponent(name, isDirectory: true) }
    private func journal(_ name: String) -> LibrarySyncJournal { LibrarySyncJournal(rootURL: location(name)) }
    private func filename(_ id: UUID) -> String { id.uuidString.lowercased() + ".json" }
    private func document(_ text: String, id: UUID = UUID()) -> WritingDocument {
        WritingDocument(
            id: id, title: "A private fixture", text: text, collection: "Tests",
            createdAt: Date(timeIntervalSince1970: 1_000), updatedAt: Date(timeIntervalSince1970: 2_000)
        )
    }
}
