import SwiftUI

struct SidebarInfoPanels: View {
    @Bindable var claude: ClaudeService

    var body: some View {
        usageSection
        if !claude.plugins.isEmpty { pluginsSection }
        if !claude.mcpServers.isEmpty { mcpSection }
        if !claude.gitChanges.isEmpty { gitSection }
    }

    // MARK: - Usage

    private var usageSection: some View {
        Section("Usage") {
            Label("\(claude.sessions.count) sessions",
                  systemImage: "clock.arrow.circlepath")
                .font(.caption)
            if let stats = claude.usageStats {
                todayRow(stats)
                tokenRows(stats.modelUsage)
            }
        }
    }

    @ViewBuilder
    private func todayRow(_ stats: UsageStats) -> some View {
        let today = todayString()
        if let day = stats.dailyActivity?.first(where: { $0.date == today }) {
            Label("\(day.messageCount) messages today",
                  systemImage: "bubble.left.and.bubble.right")
                .font(.caption)
            Label("\(day.toolCallCount) tool calls today",
                  systemImage: "wrench")
                .font(.caption)
        }
    }

    @ViewBuilder
    private func tokenRows(_ modelUsage: [String: UsageStats.ModelUsage]?) -> some View {
        if let usage = modelUsage {
            ForEach(Array(usage.keys.sorted().prefix(3)), id: \.self) { key in
                if let model = usage[key] {
                    let name = key.components(separatedBy: "-").dropFirst().prefix(2)
                        .joined(separator: "-")
                    HStack {
                        Label(Formatters.formatTokens(model.outputTokens) + " out",
                              systemImage: "arrow.up")
                            .font(.caption2)
                        Spacer()
                        Text(name).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: - Plugins

    private var pluginsSection: some View {
        Section("Plugins") {
            ForEach(claude.plugins) { plugin in
                HStack {
                    Image(systemName: plugin.isEnabled
                          ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(plugin.isEnabled ? .green : .secondary)
                        .font(.caption2)
                    Text(plugin.displayName)
                        .font(.caption)
                    Spacer()
                    if !plugin.version.isEmpty {
                        Text(plugin.version)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - MCP Servers

    private var mcpSection: some View {
        Section("MCP Servers") {
            ForEach(claude.mcpServers) { server in
                HStack {
                    Image(systemName: server.isConnected
                          ? "antenna.radiowaves.left.and.right"
                          : "antenna.radiowaves.left.and.right.slash")
                        .foregroundStyle(server.isConnected ? .green : .red)
                        .font(.caption2)
                    Text(server.name)
                        .font(.caption)
                    Spacer()
                    Text(server.transport)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Git Changes

    private var gitSection: some View {
        Section("Changes (\(claude.gitChanges.count))") {
            ForEach(claude.gitChanges) { change in
                HStack {
                    Text(change.status)
                        .font(.caption2.monospaced())
                        .foregroundStyle(colorForStatus(change.status))
                    Text(change.path)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
        }
    }

    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "M": return .orange
        case "A": return .green
        case "D": return .red
        case "??": return .blue
        default: return .secondary
        }
    }
}
