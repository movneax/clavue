import Foundation

actor ConfigRepository {
    private let decoder = JSONDecoder()
    private let home = NSHomeDirectory()

    // MARK: - Usage Stats

    func loadUsageStats() -> UsageStats? {
        let path = "\(home)/.claude/stats-cache.json"
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? decoder.decode(UsageStats.self, from: data)
    }

    // MARK: - Plugins

    func loadPlugins() -> [PluginInfo] {
        let enabledMap = loadEnabledPlugins()
        let installedMap = loadInstalledPlugins()
        var result: [PluginInfo] = []

        for (name, enabled) in enabledMap {
            let displayName = name.components(separatedBy: "@").first ?? name
            let version = installedMap[name] ?? ""
            result.append(PluginInfo(
                name: name, displayName: displayName,
                version: version, isEnabled: enabled
            ))
        }

        for (name, version) in installedMap where enabledMap[name] == nil {
            let displayName = name.components(separatedBy: "@").first ?? name
            result.append(PluginInfo(
                name: name, displayName: displayName,
                version: version, isEnabled: false
            ))
        }

        return result.sorted { $0.displayName < $1.displayName }
    }

    private func loadEnabledPlugins() -> [String: Bool] {
        let path = "\(home)/.claude/settings.json"
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let plugins = json["enabledPlugins"] as? [String: Bool]
        else { return [:] }
        return plugins
    }

    private func loadInstalledPlugins() -> [String: String] {
        let path = "\(home)/.claude/plugins/installed_plugins.json"
        guard let data = FileManager.default.contents(atPath: path),
              let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [:] }

        var map: [String: String] = [:]
        for entry in entries {
            if let name = entry["name"] as? String,
               let version = entry["version"] as? String {
                map[name] = version
            }
        }
        return map
    }

    // MARK: - MCP Servers

    func loadMCPServers(binaryPath: String) async -> [MCPServer] {
        let output = await runProcess(binary: binaryPath, args: ["mcp", "list"])
        guard !output.isEmpty else { return [] }

        var servers: [MCPServer] = []
        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            if let server = parseMCPLine(line) {
                servers.append(server)
            }
        }
        return servers
    }

    private func parseMCPLine(_ line: String) -> MCPServer? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("Name") else { return nil }

        let connected = trimmed.contains("Connected") || trimmed.contains("✓")
        let isHTTP = trimmed.contains("(HTTP)") || trimmed.contains("http")
        let transport = isHTTP ? "HTTP" : "stdio"

        let parts = trimmed.components(separatedBy: ":")
        let name: String
        if parts.count >= 3 {
            name = parts[1].trimmingCharacters(in: .whitespaces)
        } else {
            name = parts.first?.trimmingCharacters(in: .whitespaces) ?? trimmed
        }

        var url = ""
        if let httpRange = trimmed.range(of: "https?://[^\\s)]+",
                                          options: .regularExpression) {
            url = String(trimmed[httpRange])
        }

        return MCPServer(name: name, url: url,
                         transport: transport, isConnected: connected)
    }

    // MARK: - Git Status

    func loadGitStatus(projectPath: String) async -> [GitFileChange] {
        let output = await runProcess(
            binary: "/usr/bin/git",
            args: ["-C", projectPath, "status", "--porcelain"]
        )
        guard !output.isEmpty else { return [] }

        var changes: [GitFileChange] = []
        for line in output.components(separatedBy: "\n") where line.count >= 4 {
            let status = String(line.prefix(2)).trimmingCharacters(in: .whitespaces)
            let path = String(line.dropFirst(3))
            if !path.isEmpty {
                changes.append(GitFileChange(status: status.isEmpty ? "?" : status, path: path))
            }
        }
        return changes
    }

    // MARK: - Process Helper

    private func runProcess(binary: String, args: [String]) async -> String {
        await withCheckedContinuation { continuation in
            let proc = Process()
            let pipe = Pipe()
            proc.executableURL = URL(fileURLWithPath: binary)
            proc.arguments = args
            proc.standardOutput = pipe
            proc.standardError = FileHandle.nullDevice

            do {
                try proc.run()
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
}
