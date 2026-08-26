import Foundation

/// Builds the recommendation/quota panel's candidate list from live provider data.
///
/// Only providers that report a percent-bounded weekly-style quota participate — Cursor, Copilot, and
/// OpenRouter meter dollars/credits instead of a rate-limit percentage, so they don't fit the doc's
/// gate/tier model and are out of scope for this panel (see `.agent-todo.md`). A provider can
/// contribute more than one candidate when it exposes independent pools (Antigravity's Gemini and
/// Claude pools).
enum QuotaCandidateSource {
    /// One weekly-window metric, optionally paired with a shorter window that gates it (Claude/Codex/
    /// OpenCode/Z.ai's rolling 5-hour session, Devin's daily cap). Grok has no short window at all.
    private enum ShortWindowKind {
        case session
        case daily

        var label: String {
            switch self {
            case .session:
                return AppLocalization.string("quotaCandidate.shortWindow.session", defaultValue: "5-Hour")
            case .daily:
                return AppLocalization.string("quotaCandidate.shortWindow.daily", defaultValue: "Daily")
            }
        }
    }

    private struct Spec {
        let providerID: String
        let candidateID: String
        let displayNameSuffix: String?
        let weeklyDescriptorID: String
        let shortDescriptorID: String?
        let shortWindowKind: ShortWindowKind?
    }

    private static let specs: [Spec] = [
        .init(providerID: "claude", candidateID: "claude", displayNameSuffix: nil,
              weeklyDescriptorID: "claude.weekly", shortDescriptorID: "claude.session", shortWindowKind: .session),
        .init(providerID: "codex", candidateID: "codex", displayNameSuffix: nil,
              weeklyDescriptorID: "codex.weekly", shortDescriptorID: "codex.session", shortWindowKind: .session),
        .init(providerID: "opencode", candidateID: "opencode", displayNameSuffix: nil,
              weeklyDescriptorID: "opencode.weekly", shortDescriptorID: "opencode.session", shortWindowKind: .session),
        .init(providerID: "zai", candidateID: "zai", displayNameSuffix: nil,
              weeklyDescriptorID: "zai.weekly", shortDescriptorID: "zai.session", shortWindowKind: .session),
        .init(providerID: "antigravity", candidateID: "antigravity.gemini", displayNameSuffix: nil,
              weeklyDescriptorID: "antigravity.geminiWeekly", shortDescriptorID: "antigravity.geminiPro", shortWindowKind: .session),
        .init(providerID: "antigravity", candidateID: "antigravity.claude", displayNameSuffix: "Claude",
              weeklyDescriptorID: "antigravity.claudeWeekly", shortDescriptorID: "antigravity.claude", shortWindowKind: .session),
        .init(providerID: "devin", candidateID: "devin", displayNameSuffix: nil,
              weeklyDescriptorID: "devin.weekly", shortDescriptorID: "devin.daily", shortWindowKind: .daily),
        .init(providerID: "grok", candidateID: "grok", displayNameSuffix: nil,
              weeklyDescriptorID: "grok.weekly", shortDescriptorID: nil, shortWindowKind: nil)
    ]

    @MainActor
    static func makeCandidates(
        registry: WidgetRegistry,
        dataStore: WidgetDataStore,
        enablement: ProviderEnablementStore,
        orderedProviderIDs: [String]
    ) -> [QuotaCandidate] {
        let providerRank = Dictionary(
            orderedProviderIDs.enumerated().map { ($0.element, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
        let orderedSpecs = specs.enumerated().sorted { lhs, rhs in
            let lhsRank = providerRank[lhs.element.providerID] ?? Int.max
            let rhsRank = providerRank[rhs.element.providerID] ?? Int.max
            return lhsRank == rhsRank ? lhs.offset < rhs.offset : lhsRank < rhsRank
        }.map(\.element)

        return orderedSpecs.compactMap { spec in
            guard enablement.isEnabled(spec.providerID) else { return nil }
            guard let provider = registry.provider(id: spec.providerID) else { return nil }
            guard let weeklyDescriptor = registry.descriptor(id: spec.weeklyDescriptorID) else { return nil }
            let weekly = dataStore.data(for: weeklyDescriptor)
            guard weekly.hasData, let weeklyLimit = weekly.limit, weeklyLimit > 0 else { return nil }

            var shortUsed: Double?
            var shortLimit: Double?
            var shortResetsAt: Date?
            if let shortID = spec.shortDescriptorID, let shortDescriptor = registry.descriptor(id: shortID) {
                let short = dataStore.data(for: shortDescriptor)
                if short.hasData, let limit = short.limit, limit > 0 {
                    shortUsed = short.used
                    shortLimit = limit
                    shortResetsAt = short.resetsAt
                }
            }

            let displayName = spec.displayNameSuffix.map { "\(provider.displayName) · \($0)" } ?? provider.displayName
            return QuotaCandidate(
                id: spec.candidateID,
                displayName: displayName,
                icon: .providerMark(spec.providerID),
                weeklyUsed: weekly.used,
                weeklyLimit: weeklyLimit,
                weeklyResetsAt: weekly.resetsAt,
                shortWindowUsed: shortUsed,
                shortWindowLimit: shortLimit,
                shortWindowResetsAt: shortResetsAt,
                shortWindowLabel: spec.shortWindowKind?.label
            )
        }
    }
}
