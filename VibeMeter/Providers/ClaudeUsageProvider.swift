import Foundation

struct ClaudeUsageProvider: UsageProvider {
    let id = ProviderID.claude
    private let credentialReader: KeychainCredentialReader
    private let session: URLSession
    private let endpoint: URL

    init(
        credentialReader: KeychainCredentialReader = .init(),
        session: URLSession = .shared,
        endpoint: URL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    ) {
        self.credentialReader = credentialReader
        self.session = session
        self.endpoint = endpoint
    }

    func fetchUsage() async throws -> ProviderSnapshot {
        let token = try credentialReader.claudeAccessToken()
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("VibeMeter/0.1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UsageError.invalidResponse("Claude returned an invalid response.")
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw UsageError.authenticationRequired("Claude Code login expired. Run `claude` and sign in again.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw UsageError.requestFailed("Claude usage request failed (HTTP \(http.statusCode)).")
        }

        do {
            let payload = try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
            let windows = payload.usageWindows
            guard !windows.isEmpty else {
                throw UsageError.invalidResponse("Claude returned no active usage limits.")
            }
            return ProviderSnapshot(provider: .claude, windows: windows, fetchedAt: .now, planName: nil)
        } catch let error as UsageError {
            throw error
        } catch {
            throw UsageError.invalidResponse("Claude usage data could not be decoded.")
        }
    }
}

struct ClaudeUsageResponse: Decodable {
    struct Bucket: Decodable {
        let utilization: Double
        let resetsAt: Date?

        enum CodingKeys: String, CodingKey { case utilization, resetsAt = "resets_at" }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            utilization = try values.decode(Double.self, forKey: .utilization)
            resetsAt = Self.parseDate(try values.decodeIfPresent(String.self, forKey: .resetsAt))
        }

        private static func parseDate(_ value: String?) -> Date? {
            guard let value else { return nil }
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
        }
    }

    struct DynamicLimit: Decodable {
        let kind: String
        let group: String
        let percent: Double
        let resetsAt: Date?
        let isActive: Bool

        enum CodingKeys: String, CodingKey {
            case kind, group, percent, resetsAt = "resets_at", isActive = "is_active"
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            kind = try values.decode(String.self, forKey: .kind)
            group = try values.decode(String.self, forKey: .group)
            percent = try values.decode(Double.self, forKey: .percent)
            isActive = try values.decode(Bool.self, forKey: .isActive)
            let rawDate = try values.decodeIfPresent(String.self, forKey: .resetsAt)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            resetsAt = rawDate.flatMap { formatter.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) }
        }
    }

    let fiveHour: Bucket?
    let sevenDay: Bucket?
    let sevenDayOpus: Bucket?
    let sevenDaySonnet: Bucket?
    let limits: [DynamicLimit]

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case limits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fiveHour = try container.decodeIfPresent(Bucket.self, forKey: .fiveHour)
        sevenDay = try container.decodeIfPresent(Bucket.self, forKey: .sevenDay)
        sevenDayOpus = try container.decodeIfPresent(Bucket.self, forKey: .sevenDayOpus)
        sevenDaySonnet = try container.decodeIfPresent(Bucket.self, forKey: .sevenDaySonnet)
        limits = try container.decodeIfPresent([DynamicLimit].self, forKey: .limits) ?? []
    }

    var usageWindows: [UsageWindow] {
        var result: [UsageWindow] = []
        func append(_ bucket: Bucket?, id: String, name: String) {
            guard let bucket else { return }
            result.append(.init(provider: .claude, identifier: id, displayName: name,
                                usedPercent: bucket.utilization, resetsAt: bucket.resetsAt))
        }
        append(fiveHour, id: "five_hour", name: "5-hour limit")
        append(sevenDay, id: "seven_day", name: "Weekly")
        append(sevenDayOpus, id: "seven_day_opus", name: "Weekly Opus")
        append(sevenDaySonnet, id: "seven_day_sonnet", name: "Weekly Sonnet")

        let existing = Set(result.map(\.identifier))
        let duplicateAliases: Set<String> = [
            fiveHour == nil ? nil : "session",
            sevenDay == nil ? nil : "weekly_all",
            sevenDayOpus == nil ? nil : "weekly_opus",
            sevenDaySonnet == nil ? nil : "weekly_sonnet"
        ].compactMap { $0 }.reduce(into: Set<String>()) { $0.insert($1) }

        for limit in limits where limit.isActive && !existing.contains(limit.kind) && !duplicateAliases.contains(limit.kind) {
            let name: String
            switch limit.kind {
            case "session": name = "5-hour limit"
            case "weekly_all": name = "Weekly"
            default: name = limit.group.replacingOccurrences(of: "_", with: " ").capitalized
            }
            result.append(.init(provider: .claude, identifier: limit.kind, displayName: name,
                                usedPercent: limit.percent, resetsAt: limit.resetsAt))
        }
        return result
    }
}
