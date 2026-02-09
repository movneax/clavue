import Foundation

enum Formatters {
    static func abbreviatePath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return (path as NSString).lastPathComponent
    }

    static func formatDuration(_ ms: Double) -> String {
        let seconds = ms / 1000
        if seconds < 60 { return String(format: "%.1fs", seconds) }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins)m \(secs)s"
    }

    static func formatTokens(_ count: Int) -> String {
        if count >= 1000 { return String(format: "%.1fk", Double(count) / 1000) }
        return "\(count)"
    }

    static func toolDisplayName(_ name: String) -> String {
        switch name {
        case "Read": return "Reading file"
        case "Write": return "Writing file"
        case "Edit": return "Editing file"
        case "Bash": return "Running command"
        case "Glob": return "Searching files"
        case "Grep": return "Searching content"
        case "WebFetch": return "Fetching URL"
        case "WebSearch": return "Searching web"
        case "TodoWrite": return "Updating todos"
        case "Task": return "Running subtask"
        case "Skill": return "Running skill"
        case "NotebookEdit": return "Editing notebook"
        default: return "Using \(name)"
        }
    }

    static func toolSummary(_ name: String, input: [String: JSONValue]) -> String {
        switch name {
        case "Read", "Write", "Edit":
            if let path = input["file_path"]?.stringValue {
                return abbreviatePath(path)
            }
        case "Bash":
            if let cmd = input["command"]?.stringValue {
                return String(cmd.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
            }
        case "Glob":
            if let pattern = input["pattern"]?.stringValue {
                return pattern
            }
        case "Grep":
            if let pattern = input["pattern"]?.stringValue {
                return "\"\(pattern)\""
            }
        case "Skill":
            if let skill = input["skill"]?.stringValue {
                return skill
            }
        case "Task":
            if let desc = input["description"]?.stringValue {
                return desc
            }
        default:
            break
        }
        return ""
    }
}
