import Foundation

public enum WritingSection: String, Codable, CaseIterable, Sendable, Identifiable {
    case scratchpads
    case pieces

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .scratchpads: return "Scratchpads"
        case .pieces: return "Pieces"
        }
    }
}

public struct WritingDocument: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var text: String
    public var section: WritingSection
    public var collection: String
    public var pinned: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public var displayTitle: String {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Untitled" : value
    }

    /// A whitespace-delimited count, excluding standalone Markdown punctuation.
    /// This is a simple writing aid, not language-specific linguistic analysis.
    public var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace }).reduce(into: 0) { count, token in
            if token.contains(where: { $0.isLetter || $0.isNumber }) { count += 1 }
        }
    }

    public init(
        id: UUID = UUID(),
        title: String = "",
        text: String = "",
        section: WritingSection = .scratchpads,
        collection: String = "",
        pinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.section = section
        self.collection = collection
        self.pinned = pinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
