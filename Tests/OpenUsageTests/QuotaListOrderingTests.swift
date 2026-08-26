import XCTest
@testable import OpenUsage

final class QuotaListOrderingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testExhaustedCandidatesMoveLastWithoutChangingRelativeOrder() {
        let candidates = [
            candidate("spent-first", remaining: 0),
            candidate("available-first", remaining: 40),
            candidate("spent-second", remaining: 0),
            candidate("available-second", remaining: 80)
        ]

        XCTAssertEqual(
            QuotaListOrdering.exhaustedLast(candidates).map(\.id),
            ["available-first", "available-second", "spent-first", "spent-second"]
        )
    }

    func testNoExhaustedCandidatesKeepsSavedOrder() {
        let candidates = [candidate("B", remaining: 50), candidate("A", remaining: 60)]
        XCTAssertEqual(QuotaListOrdering.exhaustedLast(candidates).map(\.id), ["B", "A"])
    }

    private func candidate(_ id: String, remaining: Double) -> QuotaCandidate {
        QuotaCandidate(
            id: id,
            displayName: id,
            icon: .providerMark(id),
            weeklyUsed: 100 - remaining,
            weeklyLimit: 100,
            weeklyResetsAt: now.addingTimeInterval(24 * 3600),
            shortWindowUsed: 0,
            shortWindowLimit: 100,
            shortWindowResetsAt: now.addingTimeInterval(5 * 3600),
            shortWindowLabel: "Session"
        )
    }
}
