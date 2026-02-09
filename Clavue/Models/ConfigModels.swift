import Foundation

// MARK: - Usage Statistics

struct UsageStats: Codable {
    let dailyActivity: [DailyActivity]?
    let modelUsage: [String: ModelUsage]?
    let totalSessions: Int?
    let totalMessages: Int?

    struct DailyActivity: Codable {
        let date: String
        let messageCount: Int
        let sessionCount: Int
        let toolCallCount: Int
    }

    struct ModelUsage: Codable {
        let inputTokens: Int
        let outputTokens: Int
        let cacheReadInputTokens: Int?
        let cacheCreationInputTokens: Int?
        let costUSD: Double?
    }
}

// MARK: - Plugin Info

struct PluginInfo: Identifiable {
    var id: String { name }
    let name: String
    let displayName: String
    let version: String
    let isEnabled: Bool
}

// MARK: - MCP Server

struct MCPServer: Identifiable {
    var id: String { name }
    let name: String
    let url: String
    let transport: String
    let isConnected: Bool
}

// MARK: - Git File Change

struct GitFileChange: Identifiable {
    var id: String { path }
    let status: String
    let path: String
}
