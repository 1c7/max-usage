import Foundation

/// The subscription whose weekly quota is closest to resetting, among enabled providers that still
/// have unused quota. Surfaced by a dashboard banner so a user juggling several subscriptions knows
/// which one's remaining balance is about to roll over — knowing a quota resets soon is only useful
/// while there's still something left to use before it does, so an already-spent quota never wins.
///
/// "Weekly" is identified by the metric's period duration (~7 days), not a per-provider flag or the
/// (localized, so unsafe to match) display title — every provider's weekly-window descriptor already
/// reports this duration for pace/reset math, so no extra wiring is needed as providers are added.
enum SoonestWeeklyReset {
    struct Candidate: Equatable {
        let provider: Provider
        let resetsAt: Date
    }

    /// Half a day either side of exactly 7 days, so provider-side rounding/jitter in the reported
    /// period duration still counts as "weekly" without also catching monthly or 5-hour windows.
    private static let weeklyPeriodTolerance: TimeInterval = 12 * 3600
    private static let weeklyPeriod: TimeInterval = 7 * 24 * 3600

    /// The soonest-resetting weekly quota that still has something left, or `nil` when no enabled
    /// provider has a qualifying one (nothing weekly, no data yet, or every weekly quota is spent).
    static func soonest(
        registry: WidgetRegistry,
        isProviderEnabled: (String) -> Bool,
        data: (WidgetDescriptor) -> WidgetData,
        now: Date = Date()
    ) -> Candidate? {
        let candidates = registry.descriptors.compactMap { descriptor -> Candidate? in
            guard isProviderEnabled(descriptor.providerID),
                  let provider = registry.provider(id: descriptor.providerID) else { return nil }
            let widgetData = data(descriptor)
            guard widgetData.hasData, widgetData.isBounded,
                  let resetsAt = widgetData.resetsAt, resetsAt > now,
                  let periodDurationMs = widgetData.periodDurationMs else { return nil }
            let period = TimeInterval(periodDurationMs) / 1000
            guard abs(period - weeklyPeriod) <= weeklyPeriodTolerance else { return nil }
            // Spent (0% left, rounded) — nothing left to lose to the reset, so exclude it.
            guard widgetData.remainingFraction > 0 else { return nil }
            return Candidate(provider: provider, resetsAt: resetsAt)
        }
        return candidates.min { $0.resetsAt < $1.resetsAt }
    }
}
