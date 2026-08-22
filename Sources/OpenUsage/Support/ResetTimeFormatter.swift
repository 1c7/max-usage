import Foundation

/// Reset-time copy for the quota recommendation panel (see `docs/2- 时间显示算法.md`).
///
/// One tier, one unit, no combined phrasing ("in 3 days 5 hours" never appears) — the precision drops
/// as the wait grows, so the panel always reads as one glance-able number. Shared by both the
/// recommendation reason and the quota list's per-provider reset label, so the two screens can never
/// disagree about the same reset instant.
enum ResetTimeFormatter {
    /// `hoursUntilReset` is a plain hour count (not a `Date`) so callers control "now" once, at the
    /// point they measure the gap — the formatter itself has no clock dependency and is trivial to test.
    static func format(hoursUntilReset hours: Double) -> String {
        let loc = LanguageSetting.current.effectiveLocale
        if hours < 1.0 / 60.0 {
            return String(localized: "resetTime.minutes", defaultValue: "Resets in \(1) min", locale: loc)
        }
        if hours < 1 {
            let minutes = Int(max(1, (hours * 60).rounded()))
            return String(localized: "resetTime.minutes", defaultValue: "Resets in \(minutes) min", locale: loc)
        }
        if hours < 24 {
            let rounded = Int(hours.rounded())
            if rounded >= 24 {
                return String(localized: "resetTime.tomorrow", defaultValue: "Resets tomorrow", locale: loc)
            }
            return String(localized: "resetTime.hours", defaultValue: "Resets in \(rounded) hr", locale: loc)
        }
        if hours < 48 {
            return String(localized: "resetTime.tomorrow", defaultValue: "Resets tomorrow", locale: loc)
        }
        let days = max(1, Int((hours / 24).rounded()))
        return String(localized: "resetTime.days", defaultValue: "Resets in \(days) days", locale: loc)
    }
}
