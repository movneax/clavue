import SwiftUI
import AppKit

struct ContentView: View {
    @Bindable var claude: ClaudeService
    @Bindable var fileTracker: FileTracker
    @Binding var showPalette: Bool
    @Binding var showFilesPanel: Bool
    @Binding var sendRequested: Bool

    var body: some View {
        NavigationSplitView {
            SidebarView(claude: claude)
        } detail: {
            HStack(spacing: 0) {
                chatArea
                if showFilesPanel {
                    Divider()
                    FilesPanelView(
                        fileTracker: fileTracker,
                        projectPath: claude.projectPath
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("New Chat") {
                        claude.newChat()
                    }
                    .accessibilityIdentifier("newChatButton")
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        showFilesPanel.toggle()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .help("Toggle Files Panel (Cmd+Shift+E)")
                    .accessibilityIdentifier("filesPanelButton")
                }
            }
            .overlay {
                if showPalette {
                    CommandPalette(
                        isPresented: $showPalette,
                        onNewChat: { claude.newChat() },
                        onCancel: { claude.cancel() },
                        onToggleFiles: { showFilesPanel.toggle() },
                        onChooseFolder: { chooseFolder() }
                    )
                }
            }
        }
    }

    private var chatArea: some View {
        VStack(spacing: 0) {
            ChatView(claude: claude)
            if claude.isProcessing {
                activityBar
            }
            Divider()
            InputBar(claude: claude, sendRequested: $sendRequested)
        }
    }

    private var activityBar: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(claude.currentActivity)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .accessibilityIdentifier("activityBar")
    }

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

#Preview {
    @Previewable @State var showPalette = false
    @Previewable @State var showFilesPanel = false
    @Previewable @State var sendRequested = false
    ContentView(
        claude: ClaudeService(),
        fileTracker: FileTracker(),
        showPalette: $showPalette,
        showFilesPanel: $showFilesPanel,
        sendRequested: $sendRequested
    )
}
