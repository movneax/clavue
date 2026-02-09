import SwiftUI

@main
struct ClavueApp: App {
    @State private var claude = ClaudeService()
    @State private var fileTracker = FileTracker()
    @State private var showPalette = false
    @State private var showFilesPanel = false
    @State private var sendRequested = false

    var body: some Scene {
        WindowGroup {
            ContentView(
                claude: claude,
                fileTracker: fileTracker,
                showPalette: $showPalette,
                showFilesPanel: $showFilesPanel,
                sendRequested: $sendRequested
            )
            .onAppear { claude.fileTracker = fileTracker }
        }
        .defaultSize(width: 900, height: 650)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    claude.newChat()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Tools") {
                Button("Command Palette") {
                    showPalette.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Cancel Generation") {
                    claude.cancel()
                }
                .keyboardShortcut(".", modifiers: .command)

                Button("Send Message") {
                    sendRequested = true
                }
                .keyboardShortcut(.return, modifiers: .command)

                Divider()

                Button("Toggle Files Panel") {
                    showFilesPanel.toggle()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
}
