import Foundation

@MainActor @Observable
final class ClaudeService {
    var messages: [ChatMessage] = []
    var isProcessing = false
    var lastSessionID: String?
    var errorMessage: String?
    var claudeBinaryPath: String?
    var modelName: String?
    var lastCostUSD: Double?
    var lastDurationMs: Double?
    var lastInputTokens: Int?
    var lastOutputTokens: Int?
    var currentActivity: String = ""
    var sessions: [SessionInfo] = []

    var selectedModel: String = "opus" {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "selectedModel") }
    }

    var usageStats: UsageStats?
    var plugins: [PluginInfo] = []
    var mcpServers: [MCPServer] = []
    var gitChanges: [GitFileChange] = []
    var pendingImagePaths: [String] = []
    var fileTracker: FileTracker?

    var projectPath: String = "" {
        didSet {
            if projectPath != oldValue {
                UserDefaults.standard.set(projectPath, forKey: "lastProjectPath")
                Task {
                    await refreshSessions()
                    await refreshConfig()
                }
            }
        }
    }

    private let repo = SessionRepository()
    private let configRepo = ConfigRepository()
    private var cancelHandle: (@Sendable () -> Void)?

    var canSend: Bool {
        !projectPath.isEmpty && claudeBinaryPath != nil && !isProcessing
    }

    private var lastAssistantIndex: Int? {
        messages.lastIndex(where: { $0.role == .assistant })
    }

    init() {
        selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "opus"
        Task {
            claudeBinaryPath = await ClaudeBinaryFinder.find()
            if let saved = UserDefaults.standard.string(forKey: "lastProjectPath"),
               !saved.isEmpty,
               FileManager.default.fileExists(atPath: saved) {
                projectPath = saved
            }
            await refreshConfig()
        }
    }

    // MARK: - Session Management

    func refreshSessions() async {
        sessions = await repo.loadSessions(projectPath: projectPath)
    }

    func resumeSession(_ sessionID: String) {
        newChat()
        lastSessionID = sessionID
        Task {
            let loaded = await repo.loadSessionHistory(sessionID: sessionID,
                                                       projectPath: projectPath)
            messages = loaded

            let toolUses = await repo.loadToolUses(sessionID: sessionID,
                                                    projectPath: projectPath)
            for tool in toolUses {
                fileTracker?.recordToolUse(
                    toolName: tool.name, input: tool.input,
                    projectPath: projectPath)
            }
        }
    }

    // MARK: - Send

    func send(prompt: String) {
        guard let binary = claudeBinaryPath else {
            errorMessage = "Claude CLI not found. Install it with: npm install -g @anthropic-ai/claude-code"
            return
        }
        guard !projectPath.isEmpty else {
            errorMessage = "Select a project folder first."
            return
        }
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        errorMessage = nil
        isProcessing = true
        currentActivity = "Starting..."
        lastCostUSD = nil; lastDurationMs = nil
        lastInputTokens = nil; lastOutputTokens = nil

        var fullPrompt = prompt
        for imagePath in pendingImagePaths {
            fullPrompt = "[Attached image: \(imagePath)]\n" + fullPrompt
        }
        pendingImagePaths.removeAll()

        messages.append(ChatMessage(role: .user, text: fullPrompt))
        messages.append(ChatMessage(role: .assistant, text: "", isStreaming: true))

        var args = ["-p", fullPrompt, "--output-format", "stream-json",
                    "--verbose", "--model", selectedModel,
                    "--dangerously-skip-permissions"]
        if let sid = lastSessionID {
            args.append(contentsOf: ["--resume", sid])
        }

        let runner = ProcessRunner(binary: binary, args: args,
                                   workingDirectory: projectPath)
        let handle = runner.run()
        cancelHandle = handle.cancel

        Task { await consumeStream(handle.stream) }
    }

    // MARK: - Cancel / New Chat

    func cancel() {
        cancelHandle?()
        cancelHandle = nil
        isProcessing = false
        currentActivity = ""
        if let i = messages.indices.last, messages[i].isStreaming {
            messages[i].isStreaming = false
            for j in messages[i].toolCalls.indices where messages[i].toolCalls[j].status == .running {
                messages[i].toolCalls[j].status = .done
            }
        }
    }

    func newChat() {
        cancel()
        messages.removeAll()
        lastSessionID = nil
        errorMessage = nil
        lastCostUSD = nil; lastDurationMs = nil
        lastInputTokens = nil; lastOutputTokens = nil
        modelName = nil
        fileTracker?.clear()
    }

    // MARK: - Stream Consumption

    private func consumeStream(_ stream: AsyncStream<StreamEvent>) async {
        for await event in stream {
            guard let ai = lastAssistantIndex else { continue }

            switch event {
            case .system(let sessionID, let model):
                lastSessionID = sessionID
                if let m = model { modelName = m }
                currentActivity = "Connected"
                Task { await refreshSessions() }

            case .assistant(let text, let toolUses, let thinking):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    if messages[ai].text.isEmpty {
                        messages[ai].text = trimmed
                    } else {
                        messages[ai].text += "\n\n" + trimmed
                    }
                    currentActivity = "Responding..."
                }
                if let t = thinking, !t.isEmpty {
                    messages[ai].thinking = t
                }
                for tool in toolUses {
                    let displayName = Formatters.toolDisplayName(tool.name)
                    let summary = Formatters.toolSummary(tool.name, input: tool.input)
                    let activity = ToolActivity(
                        toolName: tool.name, status: .running,
                        summary: summary.isEmpty ? displayName : "\(displayName): \(summary)"
                    )
                    messages[ai].toolCalls.append(activity)
                    currentActivity = "\(displayName)\(summary.isEmpty ? "" : ": \(summary)")"
                    fileTracker?.recordToolUse(
                        toolName: tool.name, input: tool.input,
                        projectPath: projectPath)
                }

            case .user(let toolResults, _):
                for _ in toolResults {
                    if let idx = messages[ai].toolCalls.lastIndex(where: { $0.status == .running }) {
                        messages[ai].toolCalls[idx].status = .done
                    }
                }
                currentActivity = "Thinking..."

            case .result(let text, let cost, let sessionID, let duration, let inTok, let outTok):
                if let sid = sessionID { lastSessionID = sid }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && messages[ai].text.isEmpty {
                    messages[ai].text = trimmed
                }
                messages[ai].isStreaming = false
                for i in messages[ai].toolCalls.indices where messages[ai].toolCalls[i].status == .running {
                    messages[ai].toolCalls[i].status = .done
                }
                lastCostUSD = cost; lastDurationMs = duration
                lastInputTokens = inTok; lastOutputTokens = outTok
                currentActivity = ""

            case .unknown:
                break
            }
        }

        isProcessing = false
        currentActivity = ""
        cancelHandle = nil
        if let ai = lastAssistantIndex { messages[ai].isStreaming = false }
        await refreshSessions()
        await refreshConfig()
    }

    // MARK: - Config Loading

    func refreshConfig() async {
        usageStats = await configRepo.loadUsageStats()
        plugins = await configRepo.loadPlugins()
        if let binary = claudeBinaryPath {
            mcpServers = await configRepo.loadMCPServers(binaryPath: binary)
        }
        if !projectPath.isEmpty {
            gitChanges = await configRepo.loadGitStatus(projectPath: projectPath)
        }
    }
}
