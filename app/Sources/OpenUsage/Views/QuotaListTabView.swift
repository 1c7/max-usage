import SwiftUI

/// Tab 2: every eligible candidate's weekly (and, where the provider reports one, short-window) meter
/// side by side — the comparison view the recommendation collapses down to one answer.
struct QuotaListTabView: View {
    let candidates: [QuotaCandidate]
    let now: Date
    @AppStorage(LanguageSetting.key) private var language = LanguageSetting.fallback

    private var orderedCandidates: [QuotaCandidate] {
        QuotaListOrdering.exhaustedLast(candidates)
    }

    var body: some View {
        if candidates.isEmpty {
            Text(AppLocalization.string(
                "quotaList.empty",
                defaultValue: "Turn on a provider in Customize to see its quota here."
            ))
            .font(.title3)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(orderedCandidates) { candidate in
                    QuotaCandidateRow(candidate: candidate, now: now)
                    if candidate.id != orderedCandidates.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

private struct QuotaCandidateRow: View {
    let candidate: QuotaCandidate
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(candidate.displayName)
                    .font(.title3.weight(.bold))
                if let resetText {
                    Spacer()
                    Text(resetText)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
            }
            if candidate.weeklyRemainingPct <= 0 {
                Text(AppLocalization.string(
                    "quotaList.weeklyExhausted",
                    defaultValue: "Weekly quota used up"
                ))
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.notice)
            } else {
                QuotaMeterRow(
                    label: AppLocalization.string("quotaList.weekly", defaultValue: "Weekly"),
                    remainingPct: candidate.weeklyRemainingPct
                )
            }
            // A spent weekly quota makes the short window moot — the subscription can't be used
            // either way, so showing "5-Hour 100%" next to "Weekly 0%" would read as usable when
            // it isn't. Only surface the short window when there's still weekly quota to spend it.
            if candidate.weeklyRemainingPct > 0, candidate.shortWindowUsed != nil, let label = candidate.shortWindowLabel {
                QuotaMeterRow(label: label, remainingPct: candidate.shortWindowRemainingPct)
            }
        }
        .padding(.vertical, 14)
    }

    private var resetText: String? {
        guard let resetsAt = candidate.weeklyResetsAt else { return nil }
        if candidate.weeklyRemainingPct <= 0 {
            guard let when = Formatters.whenLabel(at: resetsAt, mode: .absolute, now: now) else { return nil }
            let tmpl = AppLocalization.string("quotaList.resetsAt", defaultValue: "Resets %@")
            return String(format: tmpl, when)
        }
        guard let hours = candidate.weeklyHoursUntilReset(now: now) else { return nil }
        return ResetTimeFormatter.format(hoursUntilReset: hours)
    }
}

/// The saved provider order remains authoritative inside each group. Exhausted weekly pools form a
/// temporary group at the bottom because they cannot satisfy the panel's "what can I use now?" job;
/// when a pool resets it naturally returns to its saved position without rewriting the preference.
enum QuotaListOrdering {
    static func exhaustedLast(_ candidates: [QuotaCandidate]) -> [QuotaCandidate] {
        candidates.filter { $0.weeklyRemainingPct > 0 }
            + candidates.filter { $0.weeklyRemainingPct <= 0 }
    }
}

private struct QuotaMeterRow: View {
    let label: String
    let remainingPct: Double

    /// Green above 70% remaining, orange at or below 20%, plain neutral gray in between — no
    /// blue/red level bands here (those are the live-pacing dashboard's language); this panel only
    /// ever reads "plenty left" vs. "running low" vs. "in the middle, nothing to flag."
    private enum Level { case healthy, low, neutral }

    private var level: Level {
        if remainingPct > 70 { return .healthy }
        if remainingPct <= 20 { return .low }
        return .neutral
    }

    private var fillStyle: AnyShapeStyle {
        switch level {
        case .healthy: AnyShapeStyle(Theme.positive)
        case .low: AnyShapeStyle(Theme.notice)
        case .neutral: AnyShapeStyle(.secondary)
        }
    }

    private var textStyle: AnyShapeStyle {
        switch level {
        case .healthy: AnyShapeStyle(Theme.positive)
        case .low: AnyShapeStyle(Theme.notice)
        case .neutral: AnyShapeStyle(.primary)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 66, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(fillStyle)
                        .frame(width: proxy.size.width * max(0, min(1, remainingPct / 100)))
                }
            }
            .frame(height: 9)
            Text("\(Int(remainingPct.rounded()))%")
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(textStyle)
                .frame(width: 56, alignment: .trailing)
        }
    }
}
