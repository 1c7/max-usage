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
        if hours < 1.0 / 60.0 {
            let tmpl = AppLocalization.string("resetTime.minutes", defaultValue: "Resets in %lld min")
            return String(format: tmpl, 1)
        }
        if hours < 1 {
            let minutes = Int(max(1, (hours * 60).rounded()))
            let tmpl = AppLocalization.string("resetTime.minutes", defaultValue: "Resets in %lld min")
            return String(format: tmpl, minutes)
        }
        if hours < 24 {
            let rounded = Int(hours.rounded())
            if rounded >= 24 {
                return AppLocalization.string("resetTime.tomorrow", defaultValue: "Resets tomorrow")
            }
            let tmpl = AppLocalization.string("resetTime.hours", defaultValue: "Resets in %lld hr")
            return String(format: tmpl, rounded)
        }
        if hours < 48 {
            return AppLocalization.string("resetTime.tomorrow", defaultValue: "Resets tomorrow")
        }
        let days = max(1, Int((hours / 24).rounded()))
        let tmpl = AppLocalization.string("resetTime.days", defaultValue: "Resets in %lld days")
        return String(format: tmpl, days)
    }
}
