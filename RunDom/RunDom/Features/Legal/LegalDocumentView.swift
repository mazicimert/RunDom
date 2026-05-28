import SwiftUI

// SwiftUI's built-in `AttributedString(markdown:)` only handles inline markdown
// (bold/italic). Our legal docs use headings and lists, so we line-parse the
// markdown ourselves and let SwiftUI render inline markdown inside each line
// via `LocalizedStringKey` — that handles **bold** and *italic* automatically.
struct LegalDocumentView: View {
    let document: LegalDocument

    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var blocks: [MarkdownBlock] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(blocks.indices, id: \.self) { index in
                    blockView(blocks[index])
                }
            }
            .padding(.horizontal, AppConstants.UI.screenPadding)
            .padding(.vertical, 16)
        }
        .background(Color.surfacePrimary.ignoresSafeArea())
        .navigationTitle(document.titleLocalizationKey.localized)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: localizationManager.selectedLanguageCode) {
            let raw = document.loadMarkdown(languageCode: localizationManager.selectedLanguageCode)
            blocks = MarkdownParser.parse(raw)
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading1(let text):
            Text(LocalizedStringKey(text))
                .font(.largeTitle.bold())
                .padding(.top, 4)
        case .heading2(let text):
            Text(LocalizedStringKey(text))
                .font(.title2.bold())
                .padding(.top, 8)
        case .heading3(let text):
            Text(LocalizedStringKey(text))
                .font(.title3.weight(.semibold))
                .padding(.top, 4)
        case .paragraph(let text):
            Text(LocalizedStringKey(text))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("•")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(LocalizedStringKey(text))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 4)
        case .numbered(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(number).")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(LocalizedStringKey(text))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 4)
        case .spacer:
            Spacer().frame(height: 4)
        }
    }
}

// MARK: - Markdown Parser

enum MarkdownBlock {
    case heading1(String)
    case heading2(String)
    case heading3(String)
    case paragraph(String)
    case bullet(String)
    case numbered(Int, String)
    case spacer
}

enum MarkdownParser {
    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: .newlines)

        var paragraphBuffer: [String] = []
        func flushParagraph() {
            if !paragraphBuffer.isEmpty {
                blocks.append(.paragraph(paragraphBuffer.joined(separator: " ")))
                paragraphBuffer = []
            }
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flushParagraph()
                if case .spacer = blocks.last { /* avoid double spacers */ } else if !blocks.isEmpty {
                    blocks.append(.spacer)
                }
                continue
            }

            if line.hasPrefix("### ") {
                flushParagraph()
                blocks.append(.heading3(String(line.dropFirst(4))))
            } else if line.hasPrefix("## ") {
                flushParagraph()
                blocks.append(.heading2(String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                flushParagraph()
                blocks.append(.heading1(String(line.dropFirst(2))))
            } else if line.hasPrefix("- ") {
                flushParagraph()
                blocks.append(.bullet(String(line.dropFirst(2))))
            } else if let match = numberedPrefix(line) {
                flushParagraph()
                blocks.append(.numbered(match.number, match.rest))
            } else {
                paragraphBuffer.append(line)
            }
        }
        flushParagraph()
        return blocks
    }

    /// Matches "1. text", "12. text" etc. Returns the number and the remainder.
    private static func numberedPrefix(_ line: String) -> (number: Int, rest: String)? {
        guard let dotIndex = line.firstIndex(of: ".") else { return nil }
        let numberStr = line[line.startIndex..<dotIndex]
        guard let number = Int(numberStr) else { return nil }
        let after = line.index(after: dotIndex)
        guard after < line.endIndex, line[after] == " " else { return nil }
        let rest = String(line[line.index(after: after)...])
        return (number, rest)
    }
}
