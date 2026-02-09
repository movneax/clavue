import Foundation

struct TouchedFile: Identifiable {
    var id: String { path }
    let path: String
    var actions: Set<FileAction> = []
    var lastTouched = Date()

    enum FileAction: String, CaseIterable, Hashable {
        case read, write, edit

        var icon: String {
            switch self {
            case .read: "eye"
            case .write: "doc.badge.plus"
            case .edit: "pencil"
            }
        }
    }

    func relativePath(to projectPath: String) -> String {
        if path.hasPrefix(projectPath) {
            let start = path.index(path.startIndex,
                                   offsetBy: projectPath.count)
            var relative = String(path[start...])
            if relative.hasPrefix("/") {
                relative = String(relative.dropFirst())
            }
            return relative
        }
        return (path as NSString).lastPathComponent
    }
}
