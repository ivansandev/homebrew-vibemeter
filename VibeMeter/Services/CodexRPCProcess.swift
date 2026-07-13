import Foundation
import Darwin

final class CodexRPCProcess: @unchecked Sendable {
    private let lock = NSLock()
    private var activeProcess: Process?

    init() {
        // A CLI can exit between a response and the next write. Convert that closed pipe into
        // a normal write error instead of allowing SIGPIPE to terminate the menu-bar app.
        signal(SIGPIPE, SIG_IGN)
    }

    func requestRateLimits(executable: URL, timeout: Duration = .seconds(15)) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask { try await self.run(executable: executable) }
            group.addTask {
                try await Task.sleep(for: timeout)
                self.stop()
                throw UsageError.timedOut("Codex did not answer within 15 seconds.")
            }
            guard let result = try await group.next() else {
                throw UsageError.requestFailed("Codex app server stopped unexpectedly.")
            }
            group.cancelAll()
            stop()
            return result
        }
    }

    private func run(executable: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    continuation.resume(returning: try self.blockingRun(executable: executable))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func blockingRun(executable: URL) throws -> Data {
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server", "--stdio"]
        var environment = ProcessInfo.processInfo.environment
        let executableDirectory = executable.deletingLastPathComponent().path
        let existingPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = "\(executableDirectory):/opt/homebrew/bin:/usr/local/bin:\(existingPath)"
        process.environment = environment
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        lock.withLock { activeProcess = process }
        defer {
            try? input.fileHandleForWriting.close()
            try? output.fileHandleForReading.close()
            lock.withLock { activeProcess = nil }
        }

        try process.run()
        try write([
            "method": "initialize",
            "id": 1,
            "params": [
                "clientInfo": ["name": "VibeMeter", "title": "VibeMeter", "version": "0.1.0"],
                "capabilities": ["experimentalApi": true, "requestAttestation": false]
            ]
        ], to: input.fileHandleForWriting)

        var buffer = Data()
        var requestedLimits = false
        while process.isRunning {
            let chunk = output.fileHandleForReading.availableData
            if chunk.isEmpty { break }
            buffer.append(chunk)

            while let newline = buffer.firstIndex(of: 0x0A) {
                let line = Data(buffer[..<newline])
                buffer.removeSubrange(...newline)
                guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
                if (object["id"] as? Int) == 1 && !requestedLimits {
                    requestedLimits = true
                    try write(["method": "initialized", "params": [:]], to: input.fileHandleForWriting)
                    try write(["method": "account/rateLimits/read", "id": 2], to: input.fileHandleForWriting)
                } else if (object["id"] as? Int) == 2 {
                    if let error = object["error"] as? [String: Any] {
                        let message = error["message"] as? String ?? "Unknown app-server error"
                        throw UsageError.requestFailed("Codex: \(message)")
                    }
                    return line
                }
            }
        }
        throw UsageError.incompatibleCLI("Codex does not support the usage protocol. Update Codex and try again.")
    }

    private func write(_ object: [String: Any], to handle: FileHandle) throws {
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(0x0A)
        try handle.write(contentsOf: data)
    }

    private func stop() {
        lock.withLock {
            if activeProcess?.isRunning == true { activeProcess?.terminate() }
        }
    }
}
