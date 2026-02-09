import Testing
import Foundation
@testable import Clavue

struct SessionRepositoryTests {
    let repo = SessionRepository()

    // MARK: - sessionsDirectory

    @Test func sessionsDirectoryEncodesPath() async {
        let dir = await repo.sessionsDirectory(for: "/Users/user/Projects/MyApp")
        let home = NSHomeDirectory()
        #expect(dir == "\(home)/.claude/projects/-Users-user-Projects-MyApp")
    }

    @Test func sessionsDirectoryReturnsNilForEmpty() async {
        let dir = await repo.sessionsDirectory(for: "")
        #expect(dir == nil)
    }

    // MARK: - loadSessions with temp directory

    @Test func loadSessionsFromEmptyDirectory() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // loadSessions uses sessionsDirectory which encodes the project path
        // So we test with non-existent path which gives empty result
        let sessions = await repo.loadSessions(projectPath: "/nonexistent/path/\(UUID().uuidString)")
        #expect(sessions.isEmpty)
    }

    // MARK: - loadSessionHistory

    @Test func loadSessionHistoryFromMissing() async {
        let messages = await repo.loadSessionHistory(sessionID: "nonexistent",
                                                      projectPath: "/no/such/path")
        #expect(messages.isEmpty)
    }

    // MARK: - Session log parsing integration

    @Test func parsesAssistantTextFromSessionLog() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let encoded = tmpDir.path.replacingOccurrences(of: "/", with: "-")
        let claudeDir = "\(NSHomeDirectory())/.claude/projects/\(encoded)"
        try FileManager.default.createDirectory(atPath: claudeDir,
                                                 withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: claudeDir) }

        let sessionID = "test-session-001"
        let jsonl = """
        {"type":"user","message":{"content":[{"type":"text","text":"Hello Claude"}]}}
        {"type":"assistant","message":{"content":[{"type":"text","text":"Hello! How can I help?"}]}}
        """
        let path = "\(claudeDir)/\(sessionID).jsonl"
        try jsonl.write(toFile: path, atomically: true, encoding: .utf8)

        let messages = await repo.loadSessionHistory(sessionID: sessionID,
                                                      projectPath: tmpDir.path)
        #expect(messages.count == 2)
        #expect(messages[0].role == .user)
        #expect(messages[0].text == "Hello Claude")
        #expect(messages[1].role == .assistant)
        #expect(messages[1].text == "Hello! How can I help?")
    }

    @Test func parsesThinkingFromSessionLog() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let encoded = tmpDir.path.replacingOccurrences(of: "/", with: "-")
        let claudeDir = "\(NSHomeDirectory())/.claude/projects/\(encoded)"
        try FileManager.default.createDirectory(atPath: claudeDir,
                                                 withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: claudeDir) }

        let sessionID = "test-session-002"
        let jsonl = """
        {"type":"assistant","message":{"content":[{"type":"thinking","thinking":"Let me think..."}]}}
        {"type":"assistant","message":{"content":[{"type":"text","text":"Here is my answer"}]}}
        """
        let path = "\(claudeDir)/\(sessionID).jsonl"
        try jsonl.write(toFile: path, atomically: true, encoding: .utf8)

        let messages = await repo.loadSessionHistory(sessionID: sessionID,
                                                      projectPath: tmpDir.path)
        #expect(messages.count == 1)  // Merged into one assistant message
        #expect(messages[0].thinking == "Let me think...")
        #expect(messages[0].text == "Here is my answer")
    }

    @Test func parsesToolUsageFromSessionLog() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let encoded = tmpDir.path.replacingOccurrences(of: "/", with: "-")
        let claudeDir = "\(NSHomeDirectory())/.claude/projects/\(encoded)"
        try FileManager.default.createDirectory(atPath: claudeDir,
                                                 withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: claudeDir) }

        let sessionID = "test-session-003"
        let jsonl = """
        {"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/test.swift"}}]}}
        {"type":"assistant","message":{"content":[{"type":"text","text":"I read the file"}]}}
        """
        let path = "\(claudeDir)/\(sessionID).jsonl"
        try jsonl.write(toFile: path, atomically: true, encoding: .utf8)

        let messages = await repo.loadSessionHistory(sessionID: sessionID,
                                                      projectPath: tmpDir.path)
        #expect(messages.count == 1)
        #expect(messages[0].toolCalls.count == 1)
        #expect(messages[0].toolCalls[0].toolName == "Read")
        #expect(messages[0].toolCalls[0].status == .done)
        #expect(messages[0].text == "I read the file")
    }

    @Test func filtersSystemUserMessages() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let encoded = tmpDir.path.replacingOccurrences(of: "/", with: "-")
        let claudeDir = "\(NSHomeDirectory())/.claude/projects/\(encoded)"
        try FileManager.default.createDirectory(atPath: claudeDir,
                                                 withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: claudeDir) }

        let sessionID = "test-session-004"
        let jsonl = """
        {"type":"user","message":{"content":[{"type":"text","text":"<system>bootstrap</system>"}]}}
        {"type":"user","message":{"content":[{"type":"text","text":"Real user question"}]}}
        {"type":"assistant","message":{"content":[{"type":"text","text":"Answer"}]}}
        """
        let path = "\(claudeDir)/\(sessionID).jsonl"
        try jsonl.write(toFile: path, atomically: true, encoding: .utf8)

        let messages = await repo.loadSessionHistory(sessionID: sessionID,
                                                      projectPath: tmpDir.path)
        let userMessages = messages.filter { $0.role == .user }
        // System messages starting with < should be filtered
        #expect(userMessages.count == 1)
        #expect(userMessages[0].text == "Real user question")
    }

    @Test func loadSessionsReturnsNewestFirst() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let encoded = tmpDir.path.replacingOccurrences(of: "/", with: "-")
        let claudeDir = "\(NSHomeDirectory())/.claude/projects/\(encoded)"
        try FileManager.default.createDirectory(atPath: claudeDir,
                                                 withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: claudeDir) }

        // Create two session files with different dates
        let old = """
        {"type":"assistant","message":{"content":[{"type":"text","text":"Old session"}]}}
        """
        let new = """
        {"type":"assistant","message":{"content":[{"type":"text","text":"New session"}]}}
        """
        try old.write(toFile: "\(claudeDir)/session-old.jsonl",
                      atomically: true, encoding: .utf8)
        // Small delay to ensure different modification times
        try await Task.sleep(for: .milliseconds(50))
        try new.write(toFile: "\(claudeDir)/session-new.jsonl",
                      atomically: true, encoding: .utf8)

        let sessions = await repo.loadSessions(projectPath: tmpDir.path)
        #expect(sessions.count == 2)
        #expect(sessions[0].id == "session-new")
        #expect(sessions[0].preview == "New session")
        #expect(sessions[1].id == "session-old")
    }
}
