import SwiftUI
import AppKit

struct SidebarView: View {
    @Bindable var claude: ClaudeService

    private static let dateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        List {
            projectSection
            cliSection
            if !claude.sessions.isEmpty {
                sessionsSection
            }
            SidebarInfoPanels(claude: claude)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 240)
    }

    // MARK: - Sections

    private var projectSection: some View {
        Section("Project") {
            HStack {
                Image(systemName: "folder")
                Text(claude.projectPath.isEmpty
                     ? "No folder selected"
                     : Formatters.abbreviatePath(claude.projectPath))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundStyle(claude.projectPath.isEmpty ? .secondary : .primary)

            Button("Choose Folder...") {
                chooseFolder()
            }
            .accessibilityIdentifier("chooseFolderButton")
        }
    }

    private var cliSection: some View {
        Section("Claude CLI") {
            HStack {
                Image(systemName: claude.claudeBinaryPath != nil
                      ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(claude.claudeBinaryPath != nil ? .green : .red)
                Text(claude.claudeBinaryPath ?? "Not found")
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Picker("Model", selection: $claude.selectedModel) {
                Text("Opus").tag("opus")
                Text("Sonnet").tag("sonnet")
                Text("Haiku").tag("haiku")
            }
            .pickerStyle(.menu)

            if let model = claude.modelName {
                HStack {
                    Image(systemName: "cpu")
                        .foregroundStyle(.secondary)
                    Text(model)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var sessionsSection: some View {
        Section("Sessions") {
            ForEach(claude.sessions.prefix(5)) { session in
                Button {
                    claude.resumeSession(session.id)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            if claude.lastSessionID == session.id {
                                Circle().fill(.blue).frame(width: 6, height: 6)
                            }
                            let preview = session.preview
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            Text(verbatim: preview.isEmpty ? "Empty session" : preview)
                                .font(.caption)
                                .lineLimit(2)
                                .foregroundStyle(
                                    claude.lastSessionID == session.id
                                    ? .primary : .secondary
                                )
                        }
                        Text(Self.dateFormatter.localizedString(
                            for: session.date, relativeTo: Date()))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select your project folder"
        if panel.runModal() == .OK, let url = panel.url {
            claude.projectPath = url.path
        }
    }
}
