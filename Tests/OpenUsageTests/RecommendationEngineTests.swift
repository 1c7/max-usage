import XCTest
@testable import OpenUsage

/// Covers `docs/1- 额度推荐算法.md`'s gate, tier ladder, and "no recommendation" cases.
final class RecommendationEngineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func candidate(
        id: String,
        weeklyRemainingPct: Double,
        weeklyHours: Double,
        shortRemainingPct: Double? = 100,
        shortHours: Double? = nil
    ) -> QuotaCandidate {
        QuotaCandidate(
            id: id,
            displayName: id,
            icon: .providerMark(id),
            weeklyUsed: 100 - weeklyRemainingPct,
            weeklyLimit: 100,
            weeklyResetsAt: now.addingTimeInterval(weeklyHours * 3600),
            shortWindowUsed: shortRemainingPct.map { 100 - $0 },
            shortWindowLimit: shortRemainingPct == nil ? nil : 100,
            shortWindowResetsAt: shortHours.map { now.addingTimeInterval($0 * 3600) },
            shortWindowLabel: "Session"
        )
    }

    // MARK: - Gate

    func testWeeklyExhaustedIsExcluded() {
        let a = candidate(id: "A", weeklyRemainingPct: 0, weeklyHours: 10)
        guard case .none = RecommendationEngine.evaluate(candidates: [a], now: now) else {
            return XCTFail("weekly-exhausted candidate must not be recommended")
        }
    }

    func testShortWindowExhaustedIsExcluded() {
        let a = candidate(id: "A", weeklyRemainingPct: 50, weeklyHours: 10, shortRemainingPct: 0, shortHours: 2)
        guard case .none = RecommendationEngine.evaluate(candidates: [a], now: now) else {
            return XCTFail("short-window-exhausted candidate must not be recommended")
        }
    }

    func testNoShortWindowIsTreatedAsUnconstrained() {
        // Grok-style candidate: no short window at all (nil) still clears the gate.
        let a = candidate(id: "A", weeklyRemainingPct: 50, weeklyHours: 10, shortRemainingPct: nil)
        guard case .recommended(let rec) = RecommendationEngine.evaluate(candidates: [a], now: now) else {
            return XCTFail("expected a recommendation")
        }
        XCTAssertEqual(rec.candidate.id, "A")
    }

    // MARK: - Tiering

    func testTier1PreferredOverLaterTiersRegardlessOfRemaining() {
        // Doc example: within a tier, remaining wins; across tiers, the earliest non-empty tier wins
        // outright even if a later tier has more remaining.
        let soon = candidate(id: "soon", weeklyRemainingPct: 5, weeklyHours: 3)      // tier 1
        let later = candidate(id: "later", weeklyRemainingPct: 95, weeklyHours: 50)  // tier 3
        let result = RecommendationEngine.evaluate(candidates: [soon, later], now: now)
        guard case .recommended(let rec) = result else { return XCTFail("expected a recommendation") }
        XCTAssertEqual(rec.candidate.id, "soon")
    }

    func testWithinTierPicksHighestRemainingNotSoonestReset() {
        // Doc's own example: both in tier 3 (24-72h); A=20%/47h, B=95%/49h → B wins.
        let a = candidate(id: "A", weeklyRemainingPct: 20, weeklyHours: 47)
        let b = candidate(id: "B", weeklyRemainingPct: 95, weeklyHours: 49)
        let result = RecommendationEngine.evaluate(candidates: [a, b], now: now)
        guard case .recommended(let rec) = result else { return XCTFail("expected a recommendation") }
        XCTAssertEqual(rec.candidate.id, "B")
    }

    func testTier4UsedWhenEarlierTiersEmpty() {
        let a = candidate(id: "A", weeklyRemainingPct: 30, weeklyHours: 100)
        let b = candidate(id: "B", weeklyRemainingPct: 80, weeklyHours: 200)
        let result = RecommendationEngine.evaluate(candidates: [a, b], now: now)
        guard case .recommended(let rec) = result else { return XCTFail("expected a recommendation") }
        XCTAssertEqual(rec.candidate.id, "B")
    }

    func testTierBoundariesUseStrictLessThan() {
        // Exactly 6h must land in tier 2, not tier 1; exactly 24h in tier 3, not tier 2.
        let atSix = candidate(id: "atSix", weeklyRemainingPct: 10, weeklyHours: 6)
        let earlyTier1 = candidate(id: "earlyTier1", weeklyRemainingPct: 90, weeklyHours: 5.9)
        let result = RecommendationEngine.evaluate(candidates: [atSix, earlyTier1], now: now)
        guard case .recommended(let rec) = result else { return XCTFail("expected a recommendation") }
        // Tier 1 (earlyTier1, 5.9h) is non-empty, so it wins outright over tier 2's higher remaining.
        XCTAssertEqual(rec.candidate.id, "earlyTier1")
    }

    // MARK: - No recommendation

    func testAllWeeklyExhaustedYieldsNoRecommendationAndNoRecoveryHint() {
        let a = candidate(id: "A", weeklyRemainingPct: 0, weeklyHours: 10)
        let b = candidate(id: "B", weeklyRemainingPct: 0, weeklyHours: 20)
        let result = RecommendationEngine.evaluate(candidates: [a, b], now: now)
        guard case .none(let hint) = result else { return XCTFail("expected no recommendation") }
        XCTAssertNil(hint, "nothing has weekly quota left, so there's nothing to recover into")
    }

    func testAllShortWindowExhaustedYieldsSoonestRecoveryHint() {
        let a = candidate(id: "A", weeklyRemainingPct: 50, weeklyHours: 10, shortRemainingPct: 0, shortHours: 3)
        let b = candidate(id: "B", weeklyRemainingPct: 80, weeklyHours: 10, shortRemainingPct: 0, shortHours: 1)
        let result = RecommendationEngine.evaluate(candidates: [a, b], now: now)
        guard case .none(let hint) = result else { return XCTFail("expected no recommendation") }
        XCTAssertEqual(hint?.candidate.id, "B", "B's short window frees up soonest (1h vs 3h)")
    }

    func testEmptyCandidateListYieldsNoRecommendation() {
        guard case .none(let hint) = RecommendationEngine.evaluate(candidates: [], now: now) else {
            return XCTFail("expected no recommendation")
        }
        XCTAssertNil(hint)
    }

    // MARK: - Single-subscription degeneration

    func testSingleUsableSubscriptionIsRecommended() {
        let a = candidate(id: "A", weeklyRemainingPct: 50, weeklyHours: 10)
        guard case .recommended(let rec) = RecommendationEngine.evaluate(candidates: [a], now: now) else {
            return XCTFail("a single usable subscription must still be recommended")
        }
        XCTAssertEqual(rec.candidate.id, "A")
    }

    func testSingleSubscriptionWithExhaustedShortWindowIsNoRecommendation() {
        let a = candidate(id: "A", weeklyRemainingPct: 50, weeklyHours: 10, shortRemainingPct: 0, shortHours: 1)
        guard case .none(let hint) = RecommendationEngine.evaluate(candidates: [a], now: now) else {
            return XCTFail("the sole candidate's exhausted short window must still gate it out")
        }
        XCTAssertEqual(hint?.candidate.id, "A")
    }
}
