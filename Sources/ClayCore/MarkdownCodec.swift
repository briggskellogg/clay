import Foundation

public enum MarkdownCodecError: Error, LocalizedError, Sendable {
    case invalidUTF8
    case missingMetadata
    case malformedMetadata
    case unsupportedVersion

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "The file is not valid UTF-8 text."
        case .missingMetadata:
            return "The file does not contain a Clay document header. Import it through the app to add ordinary Markdown."
        case .malformedMetadata:
            return "The Clay document header is damaged or incomplete. The original file has been left untouched."
        case .unsupportedVersion:
            return "This document uses a newer or unsupported Clay file format. The original file has been left untouched."
        }
    }
}

/// Clay files contain one metadata comment followed by an unmodified Markdown body.
///
/// Format: `<!-- clay:v1 BASE64_JSON -->\n\n<exact body>`.
/// Metadata JSON is base64-encoded so arbitrary titles (including `-->`) cannot
/// terminate the comment. Dates use Foundation's reference date (2001-01-01)
/// so encoding does not lose subsecond precision while changing epochs.
/// The blank line belongs to the header; no body whitespace is trimmed.
public enum MarkdownCodec {
    private static let prefix = "<!-- clay:v1 "
    private static let suffix = " -->\n\n"

    private struct Metadata: Codable {
        var version: Int
        var id: UUID
        var title: String
        var section: WritingSection
        var collection: String
        var pinned: Bool
        var createdAt: Date
        var updatedAt: Date
    }

    public static func encode(_ document: WritingDocument) throws -> Data {
        guard document.createdAt.timeIntervalSince1970.isFinite,
              document.updatedAt.timeIntervalSince1970.isFinite else {
            throw MarkdownCodecError.malformedMetadata
        }
        let metadata = Metadata(
            version: 1,
            id: document.id,
            title: document.title,
            section: document.section,
            collection: document.collection,
            pinned: document.pinned,
            createdAt: document.createdAt,
            updatedAt: document.updatedAt
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .deferredToDate
        let payload = try encoder.encode(metadata).base64EncodedString()
        var result = Data((prefix + payload + suffix).utf8)
        result.append(contentsOf: document.text.utf8)
        return result
    }

    public static func decode(_ data: Data) throws -> WritingDocument {
        guard let source = String(data: data, encoding: .utf8) else {
            throw MarkdownCodecError.invalidUTF8
        }
        guard source.hasPrefix("<!-- clay:") else {
            throw MarkdownCodecError.missingMetadata
        }
        guard source.hasPrefix(prefix) else {
            throw MarkdownCodecError.unsupportedVersion
        }
        guard let end = source.range(of: suffix), end.lowerBound >= source.index(source.startIndex, offsetBy: prefix.count) else {
            throw MarkdownCodecError.malformedMetadata
        }
        let start = source.index(source.startIndex, offsetBy: prefix.count)
        let encoded = String(source[start..<end.lowerBound])
        // No ignoreUnknownCharacters option: a damaged header must not decode as
        // a different document. An empty or multiline payload is also invalid.
        guard !encoded.isEmpty,
              !encoded.contains(where: { $0.isWhitespace }),
              let metadataData = Data(base64Encoded: encoded) else {
            throw MarkdownCodecError.malformedMetadata
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        let metadata: Metadata
        do {
            metadata = try decoder.decode(Metadata.self, from: metadataData)
        } catch {
            throw MarkdownCodecError.malformedMetadata
        }
        guard metadata.version == 1 else { throw MarkdownCodecError.unsupportedVersion }
        guard metadata.createdAt.timeIntervalSince1970.isFinite,
              metadata.updatedAt.timeIntervalSince1970.isFinite else {
            throw MarkdownCodecError.malformedMetadata
        }
        return WritingDocument(
            id: metadata.id,
            title: metadata.title,
            text: String(source[end.upperBound...]),
            section: metadata.section,
            collection: metadata.collection,
            pinned: metadata.pinned,
            createdAt: metadata.createdAt,
            updatedAt: metadata.updatedAt
        )
    }

    /// Imports always get a new identity, so importing a Clay file cannot
    /// overwrite a document already in the library. The source is never edited.
    public static func importMarkdown(
        _ data: Data,
        filename: String,
        section: WritingSection,
        now: Date = Date()
    ) throws -> WritingDocument {
        guard let text = String(data: data, encoding: .utf8) else {
            throw MarkdownCodecError.invalidUTF8
        }
        if text.hasPrefix("<!-- clay:") {
            let original = try decode(data)
            return WritingDocument(
                title: original.title,
                text: original.text,
                section: section,
                collection: original.collection,
                createdAt: now,
                updatedAt: now
            )
        }
        let name = (filename as NSString).deletingPathExtension
        return WritingDocument(
            title: name,
            text: text,
            section: section,
            createdAt: now,
            updatedAt: now
        )
    }

    /// Portable Markdown contains no Clay metadata. Include a title heading
    /// unless the body already begins with that heading, or the title is empty.
    /// Pass includeTitle=false when only the exact editing body is desired.
    public static func exportMarkdown(_ document: WritingDocument, includeTitle: Bool = true) -> Data {
        let title = document.title
            .split(whereSeparator: { $0.isNewline })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard includeTitle, !title.isEmpty else { return Data(document.text.utf8) }
        let openingLine = document.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isNewline })
            .first
            .map(String.init) ?? ""
        if openingLine == "# \(title)" { return Data(document.text.utf8) }
        return Data(("# \(title)\n\n" + document.text).utf8)
    }
}
