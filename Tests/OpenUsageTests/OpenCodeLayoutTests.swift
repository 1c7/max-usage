import XCTest
@testable import OpenUsage

/// Locks OpenCode's default metric placement (owner-confirmed, consistent with every other provider):
/// the three Go caps above the fold, the spend tiles below the caret, nothing pinned. Usage Trend is
/// off by default across every provider (owner call — not something most users watch day to day).
final class OpenCodeLayoutTests: XCTestCase {
    private let aboveFold = ["opencode.session", "opencode.weekly", "opencode.monthly"]
    private let belowCaret = ["opencode.today", "opencode.yesterday", "opencode.last30"]

    func testAllMetricsEnabledByDefault() {
        for id in aboveFold + belowCaret {
            XCTAssertTrue(DefaultLayout.metricIDs.contains(id), "\(id) should be enabled by default")
        }
    }

    func testTrendIsOffByDefault() {
        XCTAssertFalse(DefaultLayout.metricIDs.contains("opencode.trend"), "trend should be off by default")
    }

    func testCapsStayAboveTheFold() {
        for id in aboveFold {
            XCTAssertFalse(DefaultLayout.expandedMetricIDs.contains(id), "\(id) should stay above the fold")
        }
    }

    func testSpendTilesSitBelowTheCaret() {
        for id in belowCaret {
            XCTAssertTrue(DefaultLayout.expandedMetricIDs.contains(id), "\(id) should sit below the caret")
        }
    }

    func testNothingPinnedByDefault() {
        XCTAssertFalse(
            DefaultLayout.pinnedMetricIDs.contains { $0.hasPrefix("opencode.") },
            "a freshly auto-enabled provider adds no menu-bar pins (matches Grok/Devin)"
        )
    }
}
