import SwiftUI

/// Renders markdown text with proper code block formatting.
/// Splits content into prose (rendered via AttributedString markdown)
/// and fenced code blocks (rendered with monospace font + background).
struct MarkdownText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .prose(let content):
                    if let attributed = try? AttributedString(markdown: content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                        Text(attributed)
                            .textSelection(.enabled)
                    } else {
                        Text(content)
                            .textSelection(.enabled)
                    }
                case .code(let lang, let content):
                    VStack(alignment: .leading, spacing: 0) {
                        if !lang.isEmpty {
                            Text(lang)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.top, 6)
                                .padding(.bottom, 2)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(content)
                                .font(.system(.callout, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(.horizontal, 10)
                                .padding(.vertical, lang.isEmpty ? 8 : 4)
                                .padding(.bottom, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                }
            }
        }
    }

    private enum Block {
        case prose(String)
        case code(lang: String, content: String)
    }

    private var blocks: [Block] {
        var result: [Block] = []
        var current = ""
        var inCode = false
        var codeLang = ""
        var codeContent = ""

        for line in text.components(separatedBy: "\n") {
            if !inCode && line.hasPrefix("```") {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    result.append(.prose(trimmed))
                }
                current = ""
                inCode = true
                codeLang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                codeContent = ""
            } else if inCode && line.hasPrefix("```") {
                result.append(.code(lang: codeLang, content: codeContent))
                inCode = false
                codeLang = ""
                codeContent = ""
            } else if inCode {
                if !codeContent.isEmpty { codeContent += "\n" }
                codeContent += line
            } else {
                if !current.isEmpty { current += "\n" }
                current += line
            }
        }

        if inCode {
            result.append(.code(lang: codeLang, content: codeContent))
        } else {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                result.append(.prose(trimmed))
            }
        }

        return result
    }
}
