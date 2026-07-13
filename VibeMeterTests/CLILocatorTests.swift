import XCTest
@testable import VibeMeter

final class CLILocatorTests: XCTestCase {
    func testUsesExecutableOverride() throws {
        let url = try XCTUnwrap(CLILocator().find("sh", overridePath: "/bin/sh"))
        XCTAssertEqual(url.path, "/bin/sh")
    }

    func testRejectsInvalidOverrideAndStillSearchesKnownPaths() {
        XCTAssertNotNil(CLILocator().find("sh", overridePath: "/not/a/real/tool"))
    }
}
