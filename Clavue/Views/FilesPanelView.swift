import SwiftUI

struct FilesPanelView: View {
    @Bindable var fileTracker: FileTracker
    let projectPath: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if fileTracker.touchedFiles.isEmpty {
                emptyState
            } else {
                fileList
            }
            // TODO: Diff viewer on file tap
        }
        .frame(minWidth: 220, idealWidth: 280, maxWidth: 320)
    }

    private var header: some View {
        HStack {
            Text("Files (\(fileTracker.touchedFiles.count))")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No files touched yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fileList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(fileTracker.touchedFiles) { file in
                    fileRow(file)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func fileRow(_ file: TouchedFile) -> some View {
        HStack(spacing: 6) {
            actionIcons(file.actions)
            Text(file.relativePath(to: projectPath))
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func actionIcons(_ actions: Set<TouchedFile.FileAction>) -> some View {
        HStack(spacing: 2) {
            ForEach(TouchedFile.FileAction.allCases, id: \.self) { action in
                if actions.contains(action) {
                    Image(systemName: action.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 40, alignment: .leading)
    }
}
