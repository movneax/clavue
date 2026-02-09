import Foundation

enum StreamEvent: Sendable {
    case system(sessionID: String, model: String?)
    case assistant(text: String, toolUses: [ToolUse], thinking: String?)
    case user(toolResults: [ToolResult], text: String)
    case result(text: String, costUSD: Double?, sessionID: String?,
                durationMs: Double?, inputTokens: Int?, outputTokens: Int?)
    case unknown
}

// MARK: - Codable Parsing

struct StreamEventParser {
    private static let decoder = JSONDecoder()

    static func parse(line: String) -> StreamEvent {
        guard let data = line.data(using: .utf8),
              let raw = try? decoder.decode(RawStreamEvent.self, from: data) else {
            return .unknown
        }

        switch raw.type {
        case "system":
            return .system(sessionID: raw.session_id ?? "",
                           model: raw.model)

        case "assistant":
            guard let content = raw.message?.content else { return .unknown }
            var textParts: [String] = []
            var toolUses: [ToolUse] = []
            var thinking: String?

            for block in content {
                switch block.type {
                case "text":
                    if let t = block.text { textParts.append(t) }
                case "tool_use":
                    let name = block.name ?? "unknown"
                    let input = block.input ?? [:]
                    toolUses.append(ToolUse(name: name, input: input))
                case "thinking":
                    thinking = block.thinking ?? block.text
                default:
                    break
                }
            }
            return .assistant(text: textParts.joined(),
                              toolUses: toolUses,
                              thinking: thinking)

        case "user":
            guard let content = raw.message?.content else { return .unknown }
            var results: [ToolResult] = []
            var textParts: [String] = []
            for block in content {
                switch block.type {
                case "tool_result":
                    let toolUseID = block.tool_use_id ?? ""
                    let isError = block.is_error ?? false
                    let text: String
                    if let s = block.contentString {
                        text = s
                    } else if let blocks = block.contentBlocks {
                        text = blocks.compactMap(\.text).joined(separator: "\n")
                    } else {
                        text = ""
                    }
                    results.append(ToolResult(toolUseID: toolUseID,
                                              isError: isError,
                                              content: text))
                case "text":
                    if let t = block.text { textParts.append(t) }
                default:
                    break
                }
            }
            return .user(toolResults: results,
                         text: textParts.joined(separator: "\n"))

        case "result":
            return .result(text: raw.result ?? "",
                           costUSD: raw.resolvedCost,
                           sessionID: raw.session_id,
                           durationMs: raw.duration_ms,
                           inputTokens: raw.resolvedInputTokens,
                           outputTokens: raw.resolvedOutputTokens)

        default:
            return .unknown
        }
    }
}

// MARK: - Private Decodable Structs

private struct RawStreamEvent: Decodable {
    let type: String
    var session_id: String?
    var model: String?
    var message: RawMessage?
    var result: String?
    var cost_usd: Double?
    var total_cost_usd: Double?
    var duration_ms: Double?
    var input_tokens: Int?
    var output_tokens: Int?
    var usage: RawUsage?

    var resolvedCost: Double? { total_cost_usd ?? cost_usd }
    var resolvedInputTokens: Int? { input_tokens ?? usage?.input_tokens }
    var resolvedOutputTokens: Int? { output_tokens ?? usage?.output_tokens }
}

private struct RawUsage: Decodable {
    var input_tokens: Int?
    var output_tokens: Int?
}

private struct RawMessage: Decodable {
    var content: [RawContentBlock]?

    enum CodingKeys: String, CodingKey { case content }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let blocks = try? c.decode([RawContentBlock].self, forKey: .content) {
            content = blocks
        } else if let str = try? c.decode(String.self, forKey: .content) {
            content = [RawContentBlock(textOnly: str)]
        } else {
            content = nil
        }
    }
}

private struct RawContentBlock: Decodable {
    let type: String
    var text: String?
    var thinking: String?
    var name: String?
    var input: [String: JSONValue]?
    var tool_use_id: String?
    var is_error: Bool?

    // "content" can be a String or an array of blocks
    var contentString: String?
    var contentBlocks: [RawContentBlock]?

    enum CodingKeys: String, CodingKey {
        case type, text, thinking, name, input
        case tool_use_id, is_error, content
    }

    init(textOnly str: String) {
        type = "text"; text = str; thinking = nil; name = nil
        input = nil; tool_use_id = nil; is_error = nil
        contentString = nil; contentBlocks = nil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        thinking = try c.decodeIfPresent(String.self, forKey: .thinking)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        input = try c.decodeIfPresent([String: JSONValue].self, forKey: .input)
        tool_use_id = try c.decodeIfPresent(String.self, forKey: .tool_use_id)
        is_error = try c.decodeIfPresent(Bool.self, forKey: .is_error)

        if let s = try? c.decode(String.self, forKey: .content) {
            contentString = s
            contentBlocks = nil
        } else if let blocks = try? c.decode([RawContentBlock].self, forKey: .content) {
            contentString = nil
            contentBlocks = blocks
        } else {
            contentString = nil
            contentBlocks = nil
        }
    }
}
