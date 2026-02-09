import Testing
@testable import Clavue

struct StreamEventParserTests {

    // MARK: - System Events

    @Test func parsesSystemEvent() {
        let json = """
        {"type":"system","session_id":"abc-123","model":"claude-opus-4-6"}
        """
        let event = StreamEventParser.parse(line: json)
        guard case .system(let sid, let model) = event else {
            Issue.record("Expected .system, got \(event)")
            return
        }
        #expect(sid == "abc-123")
        #expect(model == "claude-opus-4-6")
    }

    @Test func parsesSystemEventWithoutModel() {
        let json = """
        {"type":"system","session_id":"xyz"}
        """
        let event = StreamEventParser.parse(line: json)
        guard case .system(let sid, let model) = event else {
            Issue.record("Expected .system")
            return
        }
        #expect(sid == "xyz")
        #expect(model == nil)
    }

    // MARK: - Assistant Events

    @Test func parsesAssistantTextOnly() {
        let json = """
        {"type":"assistant","message":{"content":[{"type":"text","text":"Hello world"}]}}
        """
        let event = StreamEventParser.parse(line: json)
        guard case .assistant(let text, let tools, let thinking) = event else {
            Issue.record("Expected .assistant, got \(event)")
            return
        }
        #expect(text == "Hello world")
        #expect(tools.isEmpty)
        #expect(thinking == nil)
    }

    @Test func parsesAssistantWithToolUse() {
        let json = """
        {"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/test.swift"}}]}}
        """
        let event = StreamEventParser.parse(line: json)
        guard case .assistant(let text, let tools, _) = event else {
            Issue.record("Expected .assistant")
            return
        }
        #expect(text == "")
        #expect(tools.count == 1)
        #expect(tools[0].name == "Read")
        #expect(tools[0].input["file_path"]?.stringValue == "/tmp/test.swift")
    }

    @Test func parsesAssistantWithThinkingField() {
        let json = """
        {"type":"assistant","message":{"content":[{"type":"thinking","thinking":"Let me consider..."}]}}
        """
        let event = StreamEventParser.parse(line: json)
        guard case .assistant(let text, _, let thinking) = event else {
            Issue.record("Expected .assistant")
            return
        }
        #expect(text == "")
        #expect(thinking == "Let me consider...")
    }

    @Test func parsesAssistantWithThinkingInTextField() {
        // Some formats put thinking content in "text" key instead of "thinking"
        let json = """
        {"type":"assistant","message":{"content":[{"type":"thinking","text":"Fallback thinking"}]}}
        """
        let event = StreamEventParser.parse(line: json)
        guard case .assistant(_, _, let thinking) = event else {
            Issue.record("Expected .assistant")
            return
        }
        #expect(thinking == "Fallback thinking")
    }

    @Test func parsesAssistantMixedContent() {
        let json = """
        {"type":"assistant","message":{"content":[{"type":"thinking","thinking":"hmm"},{"type":"text","text":"Answer"},{"type":"tool_use","name":"Bash","input":{"command":"ls"}}]}}
        """
        let event = StreamEventParser.parse(line: json)
        guard case .assistant(let text, let tools, let thinking) = event else {
            Issue.record("Expected .assistant")
            return
        }
        #expect(text == "Answer")
        #expect(thinking == "hmm")
        #expect(tools.count == 1)
        #expect(tools[0].name == "Bash")
    }

    // MARK: - User Events

    @Test func parsesUserToolResult() {
        let json = """
        {"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"tu-1","is_error":false,"content":"file contents"}]}}
        """
        let event = StreamEventParser.parse(line: json)
        guard case .user(let results, _) = event else {
            Issue.record("Expected .user")
            return
        }
        #expect(results.count == 1)
        #expect(results[0].toolUseID == "tu-1")
        #expect(results[0].isError == false)
        #expect(results[0].content == "file contents")
    }

    @Test func parsesUserToolResultWithError() {
        let json = """
        {"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"tu-2","is_error":true,"content":"Permission denied"}]}}
        """
        let event = StreamEventParser.parse(line: json)
        guard case .user(let results, _) = event else {
            Issue.record("Expected .user")
            return
        }
        #expect(results[0].isError == true)
        #expect(results[0].content == "Permission denied")
    }

    @Test func parsesUserToolResultWithArrayContent() {
        let json = """
        {"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"tu-3","content":[{"type":"text","text":"line1"},{"type":"text","text":"line2"}]}]}}
        """
        let event = StreamEventParser.parse(line: json)
        guard case .user(let results, _) = event else {
            Issue.record("Expected .user")
            return
        }
        #expect(results[0].content == "line1\nline2")
    }

    @Test func parsesUserWithStringContent() {
        let json = """
        {"type":"user","message":{"role":"user","content":"Hello world"}}
        """
        let event = StreamEventParser.parse(line: json)
        guard case .user(let results, let text) = event else {
            Issue.record("Expected .user")
            return
        }
        #expect(results.isEmpty)
        #expect(text == "Hello world")
    }

    @Test func parsesUserWithTextBlockArray() {
        let json = """
        {"type":"user","message":{"content":[{"type":"text","text":"A question"}]}}
        """
        let event = StreamEventParser.parse(line: json)
        guard case .user(_, let text) = event else {
            Issue.record("Expected .user")
            return
        }
        #expect(text == "A question")
    }

    // MARK: - Result Events

    @Test func parsesResultEvent() {
        let json = """
        {"type":"result","result":"Done","cost_usd":0.05,"session_id":"s-1","duration_ms":1234.5,"input_tokens":100,"output_tokens":50}
        """
        let event = StreamEventParser.parse(line: json)
        guard case .result(let text, let cost, let sid, let dur, let inTok, let outTok) = event else {
            Issue.record("Expected .result, got \(event)")
            return
        }
        #expect(text == "Done")
        #expect(cost == 0.05)
        #expect(sid == "s-1")
        #expect(dur == 1234.5)
        #expect(inTok == 100)
        #expect(outTok == 50)
    }

    @Test func parsesResultWithNoOptionals() {
        let json = """
        {"type":"result","result":"OK"}
        """
        let event = StreamEventParser.parse(line: json)
        guard case .result(let text, let cost, _, _, _, _) = event else {
            Issue.record("Expected .result")
            return
        }
        #expect(text == "OK")
        #expect(cost == nil)
    }

    // MARK: - Edge Cases

    @Test func parsesUnknownType() {
        let json = """
        {"type":"progress","data":"something"}
        """
        let event = StreamEventParser.parse(line: json)
        guard case .unknown = event else {
            Issue.record("Expected .unknown, got \(event)")
            return
        }
    }

    @Test func parsesInvalidJSON() {
        let event = StreamEventParser.parse(line: "not json at all")
        guard case .unknown = event else {
            Issue.record("Expected .unknown for invalid JSON")
            return
        }
    }

    @Test func parsesEmptyLine() {
        let event = StreamEventParser.parse(line: "")
        guard case .unknown = event else {
            Issue.record("Expected .unknown for empty line")
            return
        }
    }

    @Test func parsesAssistantWithNoMessage() {
        let json = """
        {"type":"assistant"}
        """
        let event = StreamEventParser.parse(line: json)
        guard case .unknown = event else {
            Issue.record("Expected .unknown when message is nil")
            return
        }
    }

    // MARK: - JSONL Session Log Format

    @Test func parsesSessionLogFormat() {
        // Real JSONL session log lines have extra fields at top level
        let json = """
        {"parentUuid":"abc","type":"assistant","message":{"model":"claude-opus-4-6","content":[{"type":"text","text":"Hello from session log"}]}}
        """
        let event = StreamEventParser.parse(line: json)
        guard case .assistant(let text, _, _) = event else {
            Issue.record("Expected .assistant from session log format, got \(event)")
            return
        }
        #expect(text == "Hello from session log")
    }

    @Test func parsesSessionLogUserWithStringContent() {
        // In session logs, user message content can be a plain string
        let json = """
        {"type":"user","message":{"content":"Just a plain string prompt"}}
        """
        let event = StreamEventParser.parse(line: json)
        // This should parse, possibly as unknown since content isn't an array
        // The key thing is it shouldn't crash
        _ = event
    }
}
