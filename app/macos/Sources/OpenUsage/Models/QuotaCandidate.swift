import Foundation

/// One rate-limited quota pool eligible for the recommendation/quota panel: a provider (or one of a
/// provider's independent pools, e.g. Antigravity's Gemini and Claude pools) with a weekly-style long
/// window and, where the provider reports one, a short window (Claude/Codex/OpenCode/Z.ai's rolling
/// 5-hour session, Devin's daily cap). See `docs/1- 额度推荐算法.md`.
struct QuotaCandidate: Identifiable, Hashable {
    let id: String
    let displayName: String
    let icon: IconSource

    let weeklyUsed: Double
    let weeklyLimit: Double
    let weeklyResetsAt: Date?

    /// `nil` for a provider with no reported short window (Grok): the gate then treats it as always
    /// open, since there's no session-level constraint to check.
    let shortWindowUsed: Double?
    let shortWindowLimit: Double?
    let shortWindowResetsAt: Date?
    /// Label for the short window's row in the quota list ("5小时" for a real 5-hour session, "Daily"
    /// for Devin) — carried explicitly rather than guessed from the duration, since Devin's window
    /// isn't actually five hours.
    let shortWindowLabel: String?

    var weeklyRemainingPct: Double {
        guard weeklyLimit > 0 else { return 0 }
        return min(max((weeklyLimit - weeklyUsed) / weeklyLimit, 0), 1) * 100
    }

    /// 100 when the provider has no short window to report — see `shortWindowUsed`.
    var shortWindowRemainingPct: Double {
        guard let used = shortWindowUsed, let limit = shortWindowLimit, limit > 0 else { return 100 }
        return min(max((limit - used) / limit, 0), 1) * 100
    }

    /// Hours from `now` until the weekly window resets. `nil` (never eligible) when the provider
    /// reports no reset date.
    func weeklyHoursUntilReset(now: Date) -> Double? {
        guard let weeklyResetsAt else { return nil }
        return max(0, weeklyResetsAt.timeIntervalSince(now)) / 3600
    }
}
