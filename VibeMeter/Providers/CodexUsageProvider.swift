import Foundation

struct CodexUsageProvider: UsageProvider {
    let id = ProviderID.codex
    let executableOverride: String?
    private let locator: CLILocator
    private let rpc: CodexRPCProcess

    init(executableOverride: String? = nil, locator: CLILocator = .init(), rpc: CodexRPCProcess = .init()) {
        self.executableOverride = executableOverride
        self.locator = locator
        self.rpc = rpc
    }

    func fetchUsage() async throws -> ProviderSnapshot {
        guard let executable = locator.find("codex", overridePath: executableOverride) else {
            throw UsageError.executableMissing("Install Codex or choose its executable in Settings.")
        }
        let line = try await rpc.requestRateLimits(executable: executable)
        do {
            let envelope = try JSONDecoder().decode(CodexEnvelope.self, from: line)
            let response = envelope.result
            let snapshots = response.rateLimitsByLimitId?.values.map { $0 } ?? [response.rateLimits]
            let windows = snapshots.flatMap(\.usageWindows)
            guard !windows.isEmpty else {
                throw UsageError.invalidResponse("Codex returned no subscription usage windows.")
            }
            return ProviderSnapshot(
                provider: .codex,
                windows: windows,
                fetchedAt: .now,
                planName: snapshots.compactMap(\.planType).first
            )
        } catch let error as UsageError {
            throw error
        } catch {
            throw UsageError.invalidResponse("Codex usage data could not be decoded.")
        }
    }
}

struct CodexEnvelope: Decodable {
    let result: Result
    struct Result: Decodable {
        let rateLimits: Snapshot
        let rateLimitsByLimitId: [String: Snapshot]?
    }
}

struct Snapshot: Decodable {
    struct Window: Decodable {
        let usedPercent: Double
        let windowDurationMins: Int?
        let resetsAt: TimeInterval?
    }
    let limitId: String?
    let limitName: String?
    let primary: Window?
    let secondary: Window?
    let planType: String?

    var usageWindows: [UsageWindow] {
        let root = limitId ?? "codex"
        let named = limitName ?? root.replacingOccurrences(of: "_", with: " ").capitalized
        return [("primary", primary), ("secondary", secondary)].compactMap { suffix, window in
            guard let window else { return nil }
            let duration = window.windowDurationMins.map(Self.durationName)
            let display = duration.map { named == "Codex" ? $0 : "\(named) · \($0)" } ?? named
            return UsageWindow(
                provider: .codex,
                identifier: "\(root):\(suffix)",
                displayName: display,
                usedPercent: window.usedPercent,
                resetsAt: window.resetsAt.map(Date.init(timeIntervalSince1970:))
            )
        }
    }

    private static func durationName(_ minutes: Int) -> String {
        switch minutes {
        case 0..<60: return "\(minutes)-minute"
        case 60..<1440 where minutes.isMultiple(of: 60): return "\(minutes / 60)-hour"
        case 1440..<10080 where minutes.isMultiple(of: 1440): return "\(minutes / 1440)-day"
        case 10080: return "Weekly"
        default: return "Usage window"
        }
    }
}
