import Foundation
import XCTest
@testable import ClayCore

final class MarkdownCodecTests: XCTestCase {
    func testRoundTripPreservesAllMetadataAndExactBody() throws {
        let original = WritingDocument(
            id: UUID(uuidString: "E84D8545-11BF-4BDA-BC22-75C1140A14CB")!,
            title: "A title --> with \"quotes\"\nand a second line",
            text: "\n\n# A thought\r\n\r\nÉlan — 日本語 🪶\n<!-- clay:v1 not metadata -->\n\n",
            section: .pieces,
            collection: "Research --> / Notes\n2026",
            pinned: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000.125),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_200.5)
        )
        let data = try MarkdownCodec.encode(original)
        let decoded = try MarkdownCodec.decode(data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(Data(decoded.text.utf8), Data(original.text.utf8))
        XCTAssertTrue(String(decoding: data, as: UTF8.self).hasPrefix("<!-- clay:v1 "))
    }

    func testWhitespaceAndUnicodeBodiesAreNeverTrimmedOrNormalized() throws {
        let bodies = [
            "", "\n", "\n\n", "\r\n", " \t\nBody\n\t ",
            "e\u{0301} — é", "\u{FEFF}A heading", "\n -->\n\nEnd\n\n"
        ]
        for body in bodies {
            let encoded = try MarkdownCodec.encode(WritingDocument(text: body))
            let decoded = try MarkdownCodec.decode(encoded)
            XCTAssertEqual(Data(decoded.text.utf8), Data(body.utf8), "Changed body: \(body.debugDescription)")
        }
    }

    func testDatePrecisionSurvivesRepeatedSaves() throws {
        // Converting this value to Unix seconds and back rounds away one bit.
        // Keep the native Date representation to avoid dirty equality changes.
        let preciseTime = TimeInterval(800_000_000).nextUp
        let original = WritingDocument(
            text: "An exact revision",
            createdAt: Date(timeIntervalSinceReferenceDate: preciseTime),
            updatedAt: Date(timeIntervalSinceReferenceDate: preciseTime.nextUp)
        )
        let first = try MarkdownCodec.decode(MarkdownCodec.encode(original))
        let second = try MarkdownCodec.decode(MarkdownCodec.encode(first))
        XCTAssertEqual(first, original)
        XCTAssertEqual(second, original)
    }

    func testInvalidUTF8IsRejectedInsteadOfLossyReplacement() {
        let invalid = Data([0xFF, 0xFE, 0x80])
        XCTAssertThrowsError(try MarkdownCodec.decode(invalid))
        XCTAssertThrowsError(try MarkdownCodec.importMarkdown(invalid, filename: "Bad.md", section: .scratchpads))
    }

    func testDamagedMetadataIsRejected() throws {
        let broken = [
            "ordinary Markdown without a Clay header",
            "<!-- clay:v1  -->\n\nBody",
            "<!-- clay:v1 not-base64 -->\n\nBody",
            "<!-- clay:v1 e30= -->\n\nBody", // Valid base64, invalid metadata schema.
            "<!-- clay:v1 e30=\n -->\n\nBody",
            "<!-- clay:v1 e30= -->\nBody", // Missing mandatory header separator.
            "<!-- clay:v1 e30="
        ]
        for value in broken {
            XCTAssertThrowsError(try MarkdownCodec.decode(Data(value.utf8)), value)
        }
        // A damaged native file must not fall through into ordinary import.
        XCTAssertThrowsError(try MarkdownCodec.importMarkdown(
            Data(broken[2].utf8), filename: "Damaged.md", section: .pieces
        ))
    }

    func testUnsupportedVersionIsRejected() throws {
        let current = String(decoding: try MarkdownCodec.encode(WritingDocument(text: "Keep me")), as: UTF8.self)
        let future = current.replacingOccurrences(of: "<!-- clay:v1 ", with: "<!-- clay:v2 ")
        XCTAssertThrowsError(try MarkdownCodec.decode(Data(future.utf8))) { error in
            guard case MarkdownCodecError.unsupportedVersion = error else {
                return XCTFail("Expected unsupportedVersion, received \(error)")
            }
        }
    }

    func testNonfiniteDatesCannotBeWritten() {
        let document = WritingDocument(createdAt: Date(timeIntervalSince1970: .infinity))
        XCTAssertThrowsError(try MarkdownCodec.encode(document))
    }

    func testPlainMarkdownImportPreservesBodyAndUsesFilename() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let body = "\n# Existing heading\r\n\r\n  Keep all whitespace.\n\n"
        let imported = try MarkdownCodec.importMarkdown(
            Data(body.utf8), filename: "Some ideas.md", section: .scratchpads, now: now
        )
        XCTAssertEqual(imported.title, "Some ideas")
        XCTAssertEqual(Data(imported.text.utf8), Data(body.utf8))
        XCTAssertEqual(imported.section, .scratchpads)
        XCTAssertEqual(imported.createdAt, now)
        XCTAssertEqual(imported.updatedAt, now)
    }

    func testNativeImportCreatesIndependentIdentityInRequestedSection() throws {
        let original = WritingDocument(
            title: "Finished essay", text: "\nExact body\n", section: .pieces,
            collection: "Essays", pinned: true
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let data = try MarkdownCodec.encode(original)
        let imported = try MarkdownCodec.importMarkdown(data, filename: "copy.md", section: .scratchpads, now: now)
        XCTAssertNotEqual(imported.id, original.id)
        XCTAssertEqual(imported.title, original.title)
        XCTAssertEqual(imported.text, original.text)
        XCTAssertEqual(imported.collection, original.collection)
        XCTAssertEqual(imported.section, .scratchpads)
        XCTAssertFalse(imported.pinned)
        XCTAssertEqual(imported.createdAt, now)
    }

    func testPortableExportIncludesTitleButNoNativeMetadata() {
        let document = WritingDocument(title: "The essay", text: "\nA first paragraph.\n\n", section: .pieces)
        let exported = String(decoding: MarkdownCodec.exportMarkdown(document), as: UTF8.self)
        XCTAssertEqual(exported, "# The essay\n\n\nA first paragraph.\n\n")
        XCTAssertFalse(exported.contains("<!-- clay:"))
    }

    func testExportDoesNotDuplicateExistingTitleOrTrimBody() {
        let text = "\n\n# The essay\n\nParagraph.\n\n"
        let document = WritingDocument(title: "The essay", text: text)
        XCTAssertEqual(MarkdownCodec.exportMarkdown(document), Data(text.utf8))
        XCTAssertEqual(MarkdownCodec.exportMarkdown(document, includeTitle: false), Data(text.utf8))
        XCTAssertEqual(MarkdownCodec.exportMarkdown(WritingDocument(text: text)), Data(text.utf8))
    }

    func testDisplayTitleAndWordCountDoNotMutateStoredWriting() {
        let document = WritingDocument(title: "  \n ", text: "# Heading\n\nOne two **three**.\n---\n- four 7")
        XCTAssertEqual(document.displayTitle, "Untitled")
        XCTAssertEqual(document.title, "  \n ")
        XCTAssertEqual(document.wordCount, 6)
    }
}
