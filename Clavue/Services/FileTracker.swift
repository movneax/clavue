import Foundation

@MainActor @Observable
final class FileTracker {
    var touchedFiles: [TouchedFile] = []

    private static let trackedTools: [String: TouchedFile.FileAction] = [
        "Read": .read,
        "read": .read,
        "Write": .write,
        "write": .write,
        "Edit": .edit,
        "edit": .edit,
    ]

    func recordToolUse(toolName: String, input: [String: JSONValue],
                       projectPath: String) {
        guard let action = Self.trackedTools[toolName] else { return }
        guard let filePath = input["file_path"]?.stringValue,
              !filePath.isEmpty else { return }

        if let idx = touchedFiles.firstIndex(where: { $0.path == filePath }) {
            touchedFiles[idx].actions.insert(action)
            touchedFiles[idx].lastTouched = Date()
        } else {
            var file = TouchedFile(path: filePath)
            file.actions.insert(action)
            touchedFiles.insert(file, at: 0)
        }
    }

    func clear() {
        touchedFiles.removeAll()
    }
}
