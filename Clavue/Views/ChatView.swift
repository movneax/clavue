import SwiftUI

struct ChatView: View {
    @Bindable var claude: ClaudeService

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if claude.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(claude.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }

                    if let error = claude.errorMessage {
                        errorBanner(error)
                    }

                    if !claude.isProcessing, let cost = claude.lastCostUSD {
                        statsBar(cost: cost)
                    }
                }
                .padding()
            }
            .onChange(of: claude.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: claude.messages.last?.text) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: claude.messages.last?.toolCalls.count) {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastID = claude.messages.last?.id {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Claude Code")
                .font(.title2)
                .fontWeight(.semibold)
            if claude.projectPath.isEmpty {
                Text("Select a project folder in the sidebar to get started.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if claude.lastSessionID != nil {
                Text("Continuing session. Type a prompt below.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Type a prompt below to start coding.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
        .accessibilityIdentifier("emptyState")
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
                .textSelection(.enabled)
        }
        .padding(10)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("errorBanner")
    }

    private func statsBar(cost: Double) -> some View {
        HStack(spacing: 12) {
            Label(String(format: "$%.4f", cost), systemImage: "dollarsign.circle")
            if let dur = claude.lastDurationMs {
                Label(Formatters.formatDuration(dur), systemImage: "clock")
            }
            if let input = claude.lastInputTokens, let output = claude.lastOutputTokens {
                Label("\(Formatters.formatTokens(input))/\(Formatters.formatTokens(output))",
                      systemImage: "arrow.left.arrow.right")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }
}
