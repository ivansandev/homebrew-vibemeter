import Foundation

enum ProviderID: String, Codable, CaseIterable, Identifiable, Sendable {
    case claude
    case codex

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

struct UsageWindow: Codable, Hashable, Identifiable, Sendable {
    let provider: ProviderID
    let identifier: String
    let displayName: String
    let usedPercent: Double
    let resetsAt: Date?

    var id: String { "\(provider.rawValue):\(identifier)" }
    var remainingPercent: Double { max(0, min(100, 100 - usedPercent)) }
}

struct ProviderSnapshot: Codable, Hashable, Sendable {
    let provider: ProviderID
    let windows: [UsageWindow]
    let fetchedAt: Date
    let planName: String?
}

enum ProviderAvailability: Equatable, Sendable {
    case loading
    case available(ProviderSnapshot, isStale: Bool)
    case unavailable(String)

    var snapshot: ProviderSnapshot? {
        if case let .available(snapshot, _) = self { return snapshot }
        return nil
    }
}

enum UsageError: LocalizedError, Sendable {
    case executableMissing(String)
    case credentialsMissing(String)
    case authenticationRequired(String)
    case incompatibleCLI(String)
    case invalidResponse(String)
    case requestFailed(String)
    case timedOut(String)

    var errorDescription: String? {
        switch self {
        case let .executableMissing(message), let .credentialsMissing(message),
             let .authenticationRequired(message), let .incompatibleCLI(message),
             let .invalidResponse(message), let .requestFailed(message),
             let .timedOut(message):
            return message
        }
    }
}
