import Testing
import Foundation
@testable import Clavue

struct FormattersTests {

    // MARK: - abbreviatePath

    @Test func abbreviateHomePath() {
        let home = NSHomeDirectory()
        let path = "\(home)/Projects/MyApp"
        #expect(Formatters.abbreviatePath(path) == "~/Projects/MyApp")
    }

    @Test func abbreviateNonHomePath() {
        let path = "/usr/local/bin/claude"
        // Should return just filename for non-home paths
        #expect(Formatters.abbreviatePath(path) == "claude")
    }

    @Test func abbreviateHomeItself() {
        let home = NSHomeDirectory()
        #expect(Formatters.abbreviatePath(home) == "~")
    }

    // MARK: - formatDuration

    @Test func formatDurationSeconds() {
        #expect(Formatters.formatDuration(5000) == "5.0s")
        #expect(Formatters.formatDuration(500) == "0.5s")
        #expect(Formatters.formatDuration(59999) == "60.0s")
    }

    @Test func formatDurationMinutes() {
        #expect(Formatters.formatDuration(60000) == "1m 0s")
        #expect(Formatters.formatDuration(90000) == "1m 30s")
        #expect(Formatters.formatDuration(125000) == "2m 5s")
    }

    @Test func formatDurationZero() {
        #expect(Formatters.formatDuration(0) == "0.0s")
    }

    // MARK: - formatTokens

    @Test func formatTokensSmall() {
        #expect(Formatters.formatTokens(500) == "500")
        #expect(Formatters.formatTokens(0) == "0")
        #expect(Formatters.formatTokens(999) == "999")
    }

    @Test func formatTokensThousands() {
        #expect(Formatters.formatTokens(1000) == "1.0k")
        #expect(Formatters.formatTokens(1500) == "1.5k")
        #expect(Formatters.formatTokens(82315) == "82.3k")
    }

    // MARK: - toolDisplayName

    @Test func toolDisplayNames() {
        #expect(Formatters.toolDisplayName("Read") == "Reading file")
        #expect(Formatters.toolDisplayName("Write") == "Writing file")
        #expect(Formatters.toolDisplayName("Edit") == "Editing file")
        #expect(Formatters.toolDisplayName("Bash") == "Running command")
        #expect(Formatters.toolDisplayName("Glob") == "Searching files")
        #expect(Formatters.toolDisplayName("Grep") == "Searching content")
        #expect(Formatters.toolDisplayName("WebFetch") == "Fetching URL")
        #expect(Formatters.toolDisplayName("WebSearch") == "Searching web")
        #expect(Formatters.toolDisplayName("SomeNewTool") == "Using SomeNewTool")
    }

    // MARK: - toolSummary

    @Test func toolSummaryForFileTools() {
        let home = NSHomeDirectory()
        let input: [String: JSONValue] = ["file_path": .string("\(home)/test.swift")]
        #expect(Formatters.toolSummary("Read", input: input) == "~/test.swift")
        #expect(Formatters.toolSummary("Write", input: input) == "~/test.swift")
        #expect(Formatters.toolSummary("Edit", input: input) == "~/test.swift")
    }

    @Test func toolSummaryForBash() {
        let input: [String: JSONValue] = ["command": .string("git status")]
        #expect(Formatters.toolSummary("Bash", input: input) == "git status")
    }

    @Test func toolSummaryForBashTruncation() {
        let longCmd = String(repeating: "x", count: 100)
        let input: [String: JSONValue] = ["command": .string(longCmd)]
        let result = Formatters.toolSummary("Bash", input: input)
        #expect(result.count == 60)
    }

    @Test func toolSummaryForGlob() {
        let input: [String: JSONValue] = ["pattern": .string("**/*.swift")]
        #expect(Formatters.toolSummary("Glob", input: input) == "**/*.swift")
    }

    @Test func toolSummaryForGrep() {
        let input: [String: JSONValue] = ["pattern": .string("TODO")]
        #expect(Formatters.toolSummary("Grep", input: input) == "\"TODO\"")
    }

    @Test func toolSummaryForUnknownTool() {
        let input: [String: JSONValue] = ["key": .string("value")]
        #expect(Formatters.toolSummary("Unknown", input: input) == "")
    }

    @Test func toolSummaryEmptyInput() {
        let input: [String: JSONValue] = [:]
        #expect(Formatters.toolSummary("Read", input: input) == "")
    }
}
