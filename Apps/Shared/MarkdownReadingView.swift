import SwiftUI

/// A native, offline reading view for headings, paragraphs, lists, quotes,
/// horizontal rules, fenced code, and inline Markdown. HTML stays plain text.
struct MarkdownReadingView: View {
    let text: String
    let font: Font

    private struct Block: Identifiable {
        enum Kind { case paragraph, heading(Int), list, quote, code, rule }
        let id: Int
        let kind: Kind
        let text: String
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            if text.isEmpty {
                Text("Your writing will appear here.")
                    .foregroundStyle(ClayTheme.secondary)
            }
            ForEach(blocks) { block in
                switch block.kind {
                case .paragraph:
                    Text(inline(block.text)).font(font).lineSpacing(7)
                case .heading(let level):
                    Text(inline(block.text))
                        .font(ClayTheme.uiFont(size: CGFloat(max(18, 30 - level * 2)), weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                case .list:
                    HStack(alignment: .top, spacing: 10) {
                        Text("•").foregroundStyle(ClayTheme.secondary)
                        Text(inline(block.text)).font(font).lineSpacing(5)
                    }
                case .quote:
                    HStack(alignment: .top, spacing: 13) {
                        RoundedRectangle(cornerRadius: 2).fill(ClayTheme.rule).frame(width: 3)
                        Text(inline(block.text)).font(font).foregroundStyle(ClayTheme.secondary)
                    }.fixedSize(horizontal: false, vertical: true)
                case .code:
                    ScrollView(.horizontal) {
                        Text(block.text).font(.system(size: 14, design: .monospaced))
                            .padding(14)
                    }
                    .background(ClayTheme.sidebar, in: RoundedRectangle(cornerRadius: 9))
                case .rule:
                    Rectangle().fill(ClayTheme.rule).frame(height: 1).accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    private func inline(_ value: String) -> AttributedString {
        (try? AttributedString(markdown: value,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(value)
    }

    private var blocks: [Block] {
        var result: [Block] = []
        var paragraph: [String] = []
        var code: [String] = []
        var inCode = false
        func append(_ kind: Block.Kind, _ value: String = "") {
            result.append(Block(id: result.count, kind: kind, text: value))
        }
        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            append(.paragraph, paragraph.joined(separator: "\n"))
            paragraph.removeAll()
        }
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        for line in normalized.components(separatedBy: "\n") {
            let trim = line.trimmingCharacters(in: .whitespaces)
            if trim.hasPrefix("```") {
                flushParagraph()
                if inCode { append(.code, code.joined(separator: "\n")); code.removeAll() }
                inCode.toggle()
                continue
            }
            if inCode { code.append(line); continue }
            if trim.isEmpty { flushParagraph(); continue }
            if ["---", "***", "___"].contains(trim) { flushParagraph(); append(.rule); continue }
            let hashes = trim.prefix { $0 == "#" }.count
            if (1...6).contains(hashes), trim.dropFirst(hashes).first == " " {
                flushParagraph(); append(.heading(hashes), String(trim.dropFirst(hashes + 1))); continue
            }
            if trim.hasPrefix(">") {
                flushParagraph(); append(.quote, String(trim.dropFirst()).trimmingCharacters(in: .whitespaces)); continue
            }
            if trim.hasPrefix("- ") || trim.hasPrefix("* ") || trim.hasPrefix("+ ") {
                flushParagraph(); append(.list, String(trim.dropFirst(2))); continue
            }
            paragraph.append(line)
        }
        flushParagraph()
        if inCode { append(.code, code.joined(separator: "\n")) }
        return result
    }
}
