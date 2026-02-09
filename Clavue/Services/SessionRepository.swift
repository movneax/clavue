import Foundation

actor SessionRepository {
    func sessionsDirectory(for projectPath: String) -> String? {
        guard !projectPath.isEmpty else { return nil }
        let encoded = projectPath.replacingOccurrences(of: "/", with: "-")
        return "\(NSHomeDirectory())/.claude/projects/\(encoded)"
    }

    func loadSessions(projectPath: String) -> [SessionInfo] {
        guard let dir = sessionsDirectory(for: projectPath) else { return [] }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: dir) else { return [] }

        var loaded: [SessionInfo] = []
        for file in files where file.hasSuffix(".jsonl") {
            let sessionID = String(file.dropLast(6))
            let fullPath = "\(dir)/\(file)"
            let attrs = try? fm.attributesOfItem(atPath: fullPath)
            let date = attrs?[.modificationDate] as? Date ?? .distantPast
            let preview = sessionPreview(path: fullPath)
            loaded.append(SessionInfo(id: sessionID, date: date, preview: preview))
        }
        return loaded.sorted { $0.date > $1.date }
    }

    func loadSessionHistory(sessionID: String, projectPath: String) -> [ChatMessage] {
        guard let dir = sessionsDirectory(for: projectPath) else { return [] }
        let path = "\(dir)/\(sessionID).jsonl"
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else { return [] }

        var loaded: [ChatMessage] = []
        var textParts: [String] = []
        var tools: [ToolActivity] = []
        var thinkingParts: [String] = []

        func finalizeAssistant() {
            guard !textParts.isEmpty || !tools.isEmpty || !thinkingParts.isEmpty else { return }
            var msg = ChatMessage(role: .assistant, text: "")
            // With tool calls: intermediate text is reasoning, last text is the response
            if !tools.isEmpty && textParts.count > 1 {
                msg.text = textParts.last ?? ""
                thinkingParts.insert(textParts.dropLast().joined(separator: "\n\n"), at: 0)
            } else {
                msg.text = textParts.joined(separator: "\n\n")
            }
            if !thinkingParts.isEmpty {
                msg.thinking = thinkingParts.joined(separator: "\n\n")
            }
            msg.toolCalls = tools
            loaded.append(msg)
            textParts.removeAll(); tools.removeAll(); thinkingParts.removeAll()
        }

        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            let event = StreamEventParser.parse(line: line)
            switch event {
            case .assistant(let text, let toolUses, let thinking):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { textParts.append(trimmed) }
                if let t = thinking, !t.isEmpty { thinkingParts.append(t) }
                for tool in toolUses {
                    let dn = Formatters.toolDisplayName(tool.name)
                    let sm = Formatters.toolSummary(tool.name, input: tool.input)
                    tools.append(ToolActivity(
                        toolName: tool.name, status: .done,
                        summary: sm.isEmpty ? dn : "\(dn): \(sm)"))
                }
            case .user(_, let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let isRealUserMessage = !trimmed.isEmpty
                    && !trimmed.hasPrefix("Base directory for this skill:")
                    && !trimmed.hasPrefix("<")
                if isRealUserMessage {
                    finalizeAssistant()
                    loaded.append(ChatMessage(role: .user, text: trimmed))
                }
                // Tool result events don't break the assistant turn
            default:
                break
            }
        }
        finalizeAssistant()
        return loaded
    }

    func loadToolUses(sessionID: String, projectPath: String) -> [ToolUse] {
        guard let dir = sessionsDirectory(for: projectPath) else { return [] }
        let path = "\(dir)/\(sessionID).jsonl"
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else { return [] }

        var toolUses: [ToolUse] = []
        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            let event = StreamEventParser.parse(line: line)
            if case .assistant(_, let tools, _) = event {
                toolUses.append(contentsOf: tools)
            }
        }
        return toolUses
    }

    // MARK: - Private Helpers

    private func sessionPreview(path: String) -> String {
        guard let handle = FileHandle(forReadingAtPath: path) else { return "" }
        defer { handle.closeFile() }

        let data = handle.readData(ofLength: 65536)
        guard let content = String(data: data, encoding: .utf8) else { return "" }

        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            let event = StreamEventParser.parse(line: line)
            if case .assistant(let text, _, _) = event {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && !trimmed.hasPrefix("{") {
                    let prose = stripCodeBlocks(trimmed)
                    guard !prose.isEmpty else { continue }
                    let oneLine = prose.components(separatedBy: .newlines)
                        .joined(separator: " ")
                    return String(oneLine.prefix(100))
                }
            }
        }
        return ""
    }

    private func stripCodeBlocks(_ text: String) -> String {
        var lines = text.components(separatedBy: .newlines)
        var result: [String] = []
        var inCode = false
        for line in lines {
            if line.hasPrefix("```") {
                inCode.toggle()
                continue
            }
            if !inCode { result.append(line) }
        }
        return result.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

}
