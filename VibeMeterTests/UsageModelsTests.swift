import XCTest
@testable import VibeMeter

final class UsageModelsTests: XCTestCase {
    func testRemainingPercentageIsClamped() {
        let over = UsageWindow(provider: .claude, identifier: "over", displayName: "Over",
                               usedPercent: 140, resetsAt: nil)
        let under = UsageWindow(provider: .codex, identifier: "under", displayName: "Under",
                                usedPercent: -20, resetsAt: nil)
        XCTAssertEqual(over.remainingPercent, 0)
        XCTAssertEqual(under.remainingPercent, 100)
    }

    func testStableIdentifierIncludesProvider() {
        let claude = UsageWindow(provider: .claude, identifier: "weekly", displayName: "Weekly",
                                 usedPercent: 10, resetsAt: nil)
        let codex = UsageWindow(provider: .codex, identifier: "weekly", displayName: "Weekly",
                                usedPercent: 10, resetsAt: nil)
        XCTAssertNotEqual(claude.id, codex.id)
    }
}
