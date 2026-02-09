import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.role == .user ? "You" : "Claude")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let thinking = message.thinking, !thinking.isEmpty {
                    thinkingFold(thinking)
                }

                if message.text.isEmpty && message.isStreaming {
                    thinkingIndicator
                } else if !message.text.isEmpty {
                    messageBubbleContent
                }

                if !message.toolCalls.isEmpty {
                    toolActivityList
                }

                if message.isStreaming && !message.text.isEmpty {
                    ProgressView()
                        .controlSize(.mini)
                }
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }

    private func thinkingFold(_ text: String) -> some View {
        DisclosureGroup {
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Extended Thinking", systemImage: "brain")
                .font(.caption2)
                .foregroundStyle(.purple)
        }
        .padding(6)
        .background(Color.purple.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }

    private var thinkingIndicator: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
            Text("Thinking...")
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(backgroundForRole, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var messageBubbleContent: some View {
        if message.role == .assistant {
            MarkdownText(text: message.text)
                .padding(10)
                .background(backgroundForRole, in: RoundedRectangle(cornerRadius: 12))
        } else {
            Text(message.text)
                .textSelection(.enabled)
                .padding(10)
                .background(backgroundForRole, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var toolActivityList: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(message.toolCalls) { tool in
                HStack(spacing: 5) {
                    ToolStatusIcon(status: tool.status)
                    Text(tool.summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    private var backgroundForRole: some ShapeStyle {
        if message.role == .user {
            return AnyShapeStyle(Color.blue.opacity(0.15))
        } else {
            return AnyShapeStyle(Color.secondary.opacity(0.1))
        }
    }
}

struct ToolStatusIcon: View {
    let status: ToolActivity.Status

    var body: some View {
        switch status {
        case .running:
            ProgressView()
                .controlSize(.mini)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }
}
