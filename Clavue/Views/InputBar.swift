import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct InputBar: View {
    @Bindable var claude: ClaudeService
    @Binding var sendRequested: Bool
    @State private var inputText = ""
    @State private var attachedImages: [URL] = []

    private var inputDisabled: Bool {
        claude.projectPath.isEmpty || claude.claudeBinaryPath == nil
    }

    private var canSendMessage: Bool {
        claude.canSend && (!inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                           || !attachedImages.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            if inputDisabled && !claude.isProcessing {
                disabledState
            } else {
                inputRow
            }
        }
        .onChange(of: sendRequested) { _, newValue in
            if newValue {
                sendMessage()
                sendRequested = false
            }
        }
    }

    private var disabledState: some View {
        VStack(spacing: 6) {
            if claude.claudeBinaryPath == nil {
                Label("Claude CLI not found", systemImage: "xmark.circle")
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("cliNotFound")
                Text("Install: npm i -g @anthropic-ai/claude-code")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("No project folder selected", systemImage: "folder.badge.questionmark")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("noFolderSelected")
            }
        }
        .font(.callout)
        .padding(16)
    }

    private var inputRow: some View {
        VStack(spacing: 6) {
            if !attachedImages.isEmpty {
                imageStrip
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message Claude...", text: $inputText, axis: .vertical)
                    .accessibilityIdentifier("messageInput")
                    .textFieldStyle(.plain)
                    .lineLimit(1...8)
                    .onSubmit {
                        if !NSEvent.modifierFlags.contains(.shift) {
                            sendMessage()
                        }
                    }
                    .onPasteCommand(of: [UTType.png, UTType.tiff, UTType.jpeg]) { providers in
                        handleImagePaste(providers)
                    }
                    .padding(10)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.separator, lineWidth: 1)
                    )

                actionButton
            }
        }
        .padding(12)
    }

    private var imageStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(attachedImages, id: \.self) { url in
                    imageThumb(url)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 52)
    }

    private func imageThumb(_ url: URL) -> some View {
        ZStack(alignment: .topTrailing) {
            if let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Button {
                attachedImages.removeAll { $0 == url }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white, .gray)
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if claude.isProcessing {
            Button {
                claude.cancel()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
            .accessibilityIdentifier("stopButton")
            .help("Stop generation")
        } else {
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(canSendMessage ? .blue : .gray)
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
            .disabled(!canSendMessage)
            .accessibilityIdentifier("sendButton")
            .help("Send message")
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!text.isEmpty || !attachedImages.isEmpty), claude.canSend else { return }
        claude.pendingImagePaths = attachedImages.map(\.path)
        attachedImages.removeAll()
        inputText = ""
        claude.send(prompt: text)
    }

    private func handleImagePaste(_ providers: [NSItemProvider]) {
        for provider in providers {
            let types: [UTType] = [.png, .tiff, .jpeg]
            for type in types where provider.hasItemConformingToTypeIdentifier(type.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                    guard let data, let image = NSImage(data: data) else { return }
                    if let url = saveImageToTemp(image) {
                        DispatchQueue.main.async { attachedImages.append(url) }
                    }
                }
                break
            }
        }
    }

    private func saveImageToTemp(_ image: NSImage) -> URL? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return nil }

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("iwallet-image-\(UUID().uuidString).png")
        do {
            try png.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
