import XCTest
@testable import VibeMeter

final class CodexUsageResponseTests: XCTestCase {
    func testDecodesMultipleRateLimitBuckets() throws {
        let data = Data(#"""
        {
          "id":2,"result":{
            "rateLimits":{"limitId":"codex","limitName":null,"primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":1784539937},"secondary":null,"planType":"plus"},
            "rateLimitsByLimitId":{
              "codex":{"limitId":"codex","limitName":null,"primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":1784539937},"secondary":{"usedPercent":10,"windowDurationMins":10080,"resetsAt":1784540000},"planType":"plus"}
            }
          }
        }
        """#.utf8)
        let response = try JSONDecoder().decode(CodexEnvelope.self, from: data)
        let windows = response.result.rateLimitsByLimitId?.values.flatMap(\.usageWindows)
        XCTAssertEqual(windows?.count, 2)
        XCTAssertEqual(windows?.first?.remainingPercent, 75)
        XCTAssertEqual(windows?.last?.displayName, "Weekly")
    }
}
