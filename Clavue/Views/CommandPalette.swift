import SwiftUI

struct CommandPalette: View {
    @Binding var isPresented: Bool
    @FocusState private var searchFocused: Bool
    @State private var query = ""

    var onNewChat: () -> Void
    var onCancel: () -> Void
    var onToggleFiles: () -> Void
    var onChooseFolder: () -> Void

    private var actions: [PaletteAction] {
        [
            PaletteAction(icon: "plus.message", title: "New Chat",
                          shortcut: "Cmd+N", action: onNewChat),
            PaletteAction(icon: "xmark.circle", title: "Cancel Generation",
                          shortcut: "Cmd+.", action: onCancel),
            PaletteAction(icon: "doc.on.doc", title: "Toggle Files Panel",
                          shortcut: "Cmd+Shift+E", action: onToggleFiles),
            PaletteAction(icon: "folder", title: "Choose Folder",
                          shortcut: "", action: onChooseFolder),
        ]
    }

    private var filtered: [PaletteAction] {
        if query.isEmpty { return actions }
        let q = query.lowercased()
        return actions.filter { $0.title.lowercased().contains(q) }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                searchField
                Divider()
                actionList
            }
            .frame(width: 340)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 20)
            .padding(.top, 60)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear { searchFocused = true }
        .onExitCommand { dismiss() }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search commands...", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { runFirstMatch() }
        }
        .padding(12)
    }

    private var actionList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filtered) { action in
                    Button { run(action) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: action.icon)
                                .frame(width: 20)
                                .foregroundStyle(.secondary)
                            Text(action.title)
                            Spacer()
                            if !action.shortcut.isEmpty {
                                Text(action.shortcut)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 200)
    }

    private func run(_ action: PaletteAction) {
        dismiss()
        action.action()
    }

    private func runFirstMatch() {
        guard let first = filtered.first else { return }
        run(first)
    }

    private func dismiss() {
        isPresented = false
    }
}

private struct PaletteAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let shortcut: String
    let action: () -> Void
}
