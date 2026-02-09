import Foundation

final class ProcessRunner: Sendable {
    private let binary: String
    private let args: [String]
    private let workingDirectory: String
    private let environment: [String: String]

    init(binary: String, args: [String], workingDirectory: String) {
        self.binary = binary
        self.args = args
        self.workingDirectory = workingDirectory

        var env = ProcessInfo.processInfo.environment
        let extraPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "\(NSHomeDirectory())/.local/bin",
            "\(NSHomeDirectory())/.npm/bin",
            "/usr/bin", "/bin", "/usr/sbin", "/sbin",
        ]
        let existing = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = (extraPaths + [existing]).joined(separator: ":")
        self.environment = env
    }

    struct RunHandle {
        let stream: AsyncStream<StreamEvent>
        let cancel: @Sendable () -> Void
    }

    func run() -> RunHandle {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = args
        process.standardInput = FileHandle.nullDevice
        process.environment = environment

        if FileManager.default.fileExists(atPath: workingDirectory) {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stream = AsyncStream<StreamEvent> { continuation in
            continuation.onTermination = { _ in
                if process.isRunning { process.terminate() }
            }

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try process.run()
                } catch {
                    continuation.yield(.unknown)
                    continuation.finish()
                    return
                }

                let handle = stdoutPipe.fileHandleForReading
                var buffer = Data()

                while true {
                    let chunk = handle.availableData
                    if chunk.isEmpty { break }

                    buffer.append(chunk)

                    while let newlineRange = buffer.range(of: Data([0x0A])) {
                        let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
                        buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)

                        guard let line = String(data: lineData, encoding: .utf8),
                              !line.trimmingCharacters(in: .whitespaces).isEmpty else {
                            continue
                        }
                        continuation.yield(StreamEventParser.parse(line: line))
                    }
                }

                process.waitUntilExit()

                // Yield stderr info if process failed with empty result
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                if process.terminationStatus != 0,
                   let errText = String(data: stderrData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !errText.isEmpty {
                    // Encode error as a result event so consumer can handle it
                    continuation.yield(.result(text: "", costUSD: nil,
                                               sessionID: nil, durationMs: nil,
                                               inputTokens: nil, outputTokens: nil))
                }

                continuation.finish()
            }
        }

        let cancel: @Sendable () -> Void = {
            if process.isRunning { process.terminate() }
        }

        return RunHandle(stream: stream, cancel: cancel)
    }
}
