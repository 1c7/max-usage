import SwiftUI

/// A quiet, always-on dashboard strip naming the one enabled subscription whose weekly quota resets
/// soonest, among those that still have quota left (see `SoonestWeeklyReset`). Not a `DismissableHintCard`
/// — this is live status that changes as usage and time move, not a one-time notice, so there's no close
/// button; it simply disappears on its own once no provider qualifies (e.g. every weekly quota is spent).
struct SoonestWeeklyResetBanner: View {
    @Environment(LayoutStore.self) private var layout
    @Environment(WidgetDataStore.self) private var dataStore
    @AppStorage(DensitySetting.key) private var density = DensitySetting.regular

    private var candidate: SoonestWeeklyReset.Candidate? {
        SoonestWeeklyReset.soonest(
            registry: layout.registry,
            isProviderEnabled: layout.isProviderEnabled,
            data: { dataStore.data(for: $0) }
        )
    }

    var body: some View {
        // Re-derives from the live clock every 30s, matching every other reset countdown in the app,
        // so the named provider and duration never go stale while the popover stays open.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            if let candidate, let text = bannerText(candidate, now: context.date) {
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .cardSurface()
                    .padding(.bottom, density.sectionSpacing)
            }
        }
    }

    private func bannerText(_ candidate: SoonestWeeklyReset.Candidate, now: Date) -> String? {
        guard let duration = Formatters.compactDuration(candidate.resetsAt.timeIntervalSince(now)) else { return nil }
        return String(
            localized: "soonestWeeklyReset.banner",
            defaultValue: "Weekly quota resets soonest: \(candidate.provider.displayName) (\(duration))"
        )
    }
}
