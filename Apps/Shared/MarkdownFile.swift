import SwiftUI
import UniformTypeIdentifiers

struct MarkdownFile: FileDocument {
    static let contentType = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
    static var readableContentTypes: [UTType] { [contentType, .plainText, .text] }
    static var writableContentTypes: [UTType] { [contentType, .plainText] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              String(data: data, encoding: .utf8) != nil else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    static func safeFilename(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:").union(.controlCharacters)
        let clean = title.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return clean.isEmpty ? "Untitled" : String(clean.prefix(100))
    }
}
