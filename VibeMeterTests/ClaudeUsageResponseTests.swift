import XCTest
@testable import VibeMeter

final class ClaudeUsageResponseTests: XCTestCase {
    func testDecodesSubscriptionWindowsAndFractionalResetDate() throws {
        let data = Data(#"""
        {
          "five_hour":{"utilization":37.5,"resets_at":"2026-07-13T12:39:59.779758+00:00"},
          "seven_day":{"utilization":62,"resets_at":null},
          "seven_day_opus":null,
          "seven_day_sonnet":null,
          "limits":[]
        }
        """#.utf8)
        let response = try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
        XCTAssertEqual(response.usageWindows.count, 2)
        XCTAssertEqual(response.usageWindows[0].remainingPercent, 62.5)
        XCTAssertNotNil(response.usageWindows[0].resetsAt)
    }

    func testAddsActiveDynamicLimitAndIgnoresInactiveLimit() throws {
        let data = Data(#"""
        {
          "five_hour":null,"seven_day":null,"limits":[
            {"kind":"seven_day_cowork","group":"weekly_cowork","percent":20,"resets_at":null,"is_active":true},
            {"kind":"hidden","group":"hidden","percent":99,"resets_at":null,"is_active":false}
          ]
        }
        """#.utf8)
        let response = try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
        XCTAssertEqual(response.usageWindows.map(\.identifier), ["seven_day_cowork"])
        XCTAssertEqual(response.usageWindows.first?.remainingPercent, 80)
    }

    func testDoesNotDuplicateTheCanonicalFiveHourWindowWithSessionLimit() throws {
        let data = Data(#"""
        {
          "five_hour":{"utilization":14,"resets_at":"2026-07-13T18:20:00.123679+00:00"},
          "seven_day":null,
          "limits":[
            {"kind":"session","group":"session","percent":14,"resets_at":"2026-07-13T18:20:00.123679+00:00","is_active":true}
          ]
        }
        """#.utf8)
        let response = try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
        XCTAssertEqual(response.usageWindows.count, 1)
        XCTAssertEqual(response.usageWindows.first?.identifier, "five_hour")
        XCTAssertEqual(response.usageWindows.first?.displayName, "5-hour limit")
    }
}
