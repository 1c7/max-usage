import Foundation

/// Tiered-EDF "which subscription should I use right now" recommendation — see
/// `docs/1- 额度推荐算法.md`. Pure function of the candidate list and the current time, so it's
/// trivially testable and has no view/store dependencies.
enum RecommendationEngine {
    struct Recommendation: Hashable {
        let candidate: QuotaCandidate
        /// "Weekly still has 74%, resets in 2 days" — same reset-time phrasing the quota list uses.
        let reason: String
    }

    enum Result: Hashable {
        case recommended(Recommendation)
        /// No candidate currently clears the gate. `soonestRecovery` is the doc's optional hint: among
        /// the candidates blocked only by their short window, the one whose short window frees up
        /// soonest. `nil` when nothing is even that close (every candidate's weekly quota is spent, or
        /// there are no candidates at all).
        case none(soonestRecovery: Recommendation?)
    }

    /// Reset-hour boundaries for the tier ladder. Adjustable per the doc's "tune to how often you
    /// actually check the app" note; the four-tier *structure* is what the algorithm depends on.
    private static let tier1Bound: Double = 6
    private static let tier2Bound: Double = 24
    private static let tier3Bound: Double = 72

    private static func tier(forWeeklyHoursUntilReset hours: Double) -> Int {
        if hours < tier1Bound { return 1 }
        if hours < tier2Bound { return 2 }
        if hours < tier3Bound { return 3 }
        return 4
    }

    static func evaluate(candidates: [QuotaCandidate], now: Date = Date()) -> Result {
        let gated = candidates.filter { $0.weeklyRemainingPct > 0 && $0.shortWindowRemainingPct > 0 }

        guard !gated.isEmpty else {
            return .none(soonestRecovery: soonestRecovery(among: candidates, now: now))
        }

        // Missing a weekly reset date is a data gap we've never seen from a real provider; fall the
        // candidate through to the farthest tier rather than crashing the ranking.
        let byTier = Dictionary(grouping: gated) { candidate -> Int in
            tier(forWeeklyHoursUntilReset: candidate.weeklyHoursUntilReset(now: now) ?? .infinity)
        }

        for tierIndex in 1...3 {
            guard let inTier = byTier[tierIndex], !inTier.isEmpty else { continue }
            return .recommended(recommendation(for: bestByWeeklyRemaining(inTier), now: now))
        }
        guard let tier4 = byTier[4], !tier4.isEmpty else {
            // Every gated candidate somehow fell outside 1...4 — unreachable given `tier(forWeeklyHoursUntilReset:)`
            // always returns 1...4, but fail safe rather than force-unwrap.
            return .none(soonestRecovery: soonestRecovery(among: candidates, now: now))
        }
        return .recommended(recommendation(for: bestByWeeklyRemaining(tier4), now: now))
    }

    private static func bestByWeeklyRemaining(_ candidates: [QuotaCandidate]) -> QuotaCandidate {
        // `max(by:)` keeps the first max on a tie, so a stable input order yields a stable pick.
        candidates.max { $0.weeklyRemainingPct < $1.weeklyRemainingPct }!
    }

    private static func recommendation(for candidate: QuotaCandidate, now: Date) -> Recommendation {
        Recommendation(candidate: candidate, reason: reasonText(for: candidate, now: now))
    }

    /// "Weekly quota still has 74%, resets in 2 days" — the level word mirrors the doc's own example
    /// phrasing (still has / left / only has) by remaining band.
    private static func reasonText(for candidate: QuotaCandidate, now: Date) -> String {
        let pct = Int(candidate.weeklyRemainingPct.rounded())
        let level: String
        if candidate.weeklyRemainingPct > 70 {
            let tmpl = AppLocalization.string("recommendation.reason.stillHas", defaultValue: "Weekly quota still has %lld%%")
            level = String(format: tmpl, pct)
        } else if candidate.weeklyRemainingPct < 20 {
            let tmpl = AppLocalization.string("recommendation.reason.onlyHas", defaultValue: "Weekly quota only has %lld%% left")
            level = String(format: tmpl, pct)
        } else {
            let tmpl = AppLocalization.string("recommendation.reason.has", defaultValue: "Weekly quota has %lld%% left")
            level = String(format: tmpl, pct)
        }
        guard let hours = candidate.weeklyHoursUntilReset(now: now) else { return level }
        let resetText = ResetTimeFormatter.format(hoursUntilReset: hours)
        let tmpl = AppLocalization.string("recommendation.reason.combined", defaultValue: "%@, %@")
        return String(format: tmpl, level, resetText.lowercased())
    }

    /// Among candidates that still have weekly quota but are currently blocked by an exhausted short
    /// window, the one whose short window resets soonest — the doc's optional "no recommendation"
    /// helper hint. `nil` when no such candidate exists.
    private static func soonestRecovery(among candidates: [QuotaCandidate], now: Date) -> Recommendation? {
        let blocked = candidates.filter { $0.weeklyRemainingPct > 0 && $0.shortWindowRemainingPct <= 0 }
        guard let soonest = blocked.min(by: { lhs, rhs in
            (lhs.shortWindowResetsAt ?? .distantFuture) < (rhs.shortWindowResetsAt ?? .distantFuture)
        }) else { return nil }
        guard let resetsAt = soonest.shortWindowResetsAt else { return nil }
        let hours = max(0, resetsAt.timeIntervalSince(now)) / 3600
        let windowLabel = soonest.shortWindowLabel ?? AppLocalization.string("recommendation.reason.session", defaultValue: "Session")
        let resetText = ResetTimeFormatter.format(hoursUntilReset: hours)
        let tmpl = AppLocalization.string("recommendation.reason.recoversAt", defaultValue: "%@ %@")
        let reason = String(format: tmpl, windowLabel, resetText.lowercased())
        return Recommendation(candidate: soonest, reason: reason)
    }
}
