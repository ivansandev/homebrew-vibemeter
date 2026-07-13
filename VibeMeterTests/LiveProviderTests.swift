import XCTest
import Darwin
@testable import VibeMeter

final class LiveProviderTests: XCTestCase {
    private func requireOptIn() throws {
        let marker = "/tmp/vibemeter-live-tests-enabled-\(getuid())"
        if ProcessInfo.processInfo.environment["VIBEMETER_LIVE_TESTS"] != "1",
           !FileManager.default.fileExists(atPath: marker) {
            throw XCTSkip("Set VIBEMETER_LIVE_TESTS=1 to query signed-in local accounts.")
        }
    }

    func testLiveClaudeUsage() async throws {
        try requireOptIn()
        let snapshot = try await ClaudeUsageProvider().fetchUsage()
        XCTAssertFalse(snapshot.windows.isEmpty)
        XCTAssertTrue(snapshot.windows.allSatisfy { (0...100).contains($0.remainingPercent) })
    }

    func testLiveCodexUsage() async throws {
        try requireOptIn()
        let snapshot = try await CodexUsageProvider().fetchUsage()
        XCTAssertFalse(snapshot.windows.isEmpty)
        XCTAssertTrue(snapshot.windows.allSatisfy { (0...100).contains($0.remainingPercent) })
    }
}
