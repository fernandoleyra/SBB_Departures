import XCTest

final class SBBStyleTests: XCTestCase {
    func test_badgeColor_intercity() {
        XCTAssertEqual(SBBStyle.badgeColor(for: "IC"), SBBStyle.red)
        XCTAssertEqual(SBBStyle.badgeColor(for: "IC 5"), SBBStyle.red)
        XCTAssertEqual(SBBStyle.badgeColor(for: "IR"), SBBStyle.red)
        XCTAssertEqual(SBBStyle.badgeColor(for: "EC"), SBBStyle.red)
        XCTAssertEqual(SBBStyle.badgeColor(for: "EN"), SBBStyle.red)
    }

    func test_badgeColor_regional() {
        XCTAssertEqual(SBBStyle.badgeColor(for: "RE"), SBBStyle.redDark)
        XCTAssertEqual(SBBStyle.badgeColor(for: "RB"), SBBStyle.redDark)
    }

    func test_badgeColor_sbahn() {
        XCTAssertEqual(SBBStyle.badgeColor(for: "S"), SBBStyle.green)
        XCTAssertEqual(SBBStyle.badgeColor(for: "S3"), SBBStyle.green)
        XCTAssertEqual(SBBStyle.badgeColor(for: "S 7"), SBBStyle.green)
    }

    func test_badgeColor_tram_not_confused_with_sbahn() {
        // STR must be checked before S to avoid collision
        XCTAssertEqual(SBBStyle.badgeColor(for: "STR"), SBBStyle.violet)
        XCTAssertEqual(SBBStyle.badgeColor(for: "T"), SBBStyle.violet)
        XCTAssertEqual(SBBStyle.badgeColor(for: "NFT"), SBBStyle.violet)
    }

    func test_badgeColor_bus() {
        XCTAssertEqual(SBBStyle.badgeColor(for: "B"), SBBStyle.blue)
        XCTAssertEqual(SBBStyle.badgeColor(for: "NFB"), SBBStyle.blue)
        XCTAssertEqual(SBBStyle.badgeColor(for: "NFB 67"), SBBStyle.blue)
    }

    func test_badgeColor_boat() {
        XCTAssertEqual(SBBStyle.badgeColor(for: "BAT"), SBBStyle.teal)
        XCTAssertEqual(SBBStyle.badgeColor(for: "CGN"), SBBStyle.teal)
    }

    func test_badgeColor_night() {
        XCTAssertEqual(SBBStyle.badgeColor(for: "N"), SBBStyle.graphite)
        XCTAssertEqual(SBBStyle.badgeColor(for: "N5"), SBBStyle.graphite)
    }

    func test_badgeColor_fallback_for_number_only_routes() {
        XCTAssertEqual(SBBStyle.badgeColor(for: "31"), SBBStyle.graphite)
        XCTAssertEqual(SBBStyle.badgeColor(for: ""), SBBStyle.graphite)
    }

    func test_badgeColor_case_insensitive() {
        XCTAssertEqual(SBBStyle.badgeColor(for: "ic 5"), SBBStyle.red)
        XCTAssertEqual(SBBStyle.badgeColor(for: "s3"), SBBStyle.green)
    }
}
