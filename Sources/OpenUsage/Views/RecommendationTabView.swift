import SwiftUI

/// Tab 1: the single-answer "use this one right now" screen. Pure presentation over
/// `RecommendationEngine.evaluate` — see `docs/1- 额度推荐算法.md`.
struct RecommendationTabView: View {
    let candidates: [QuotaCandidate]
    let now: Date
    @AppStorage(LanguageSetting.key) private var language = LanguageSetting.fallback

    private var result: RecommendationEngine.Result {
        RecommendationEngine.evaluate(candidates: candidates, now: now)
    }

    var body: some View {
        let loc = LanguageSetting.current.effectiveLocale
        VStack(alignment: .leading, spacing: 16) {
            switch result {
            case .recommended(let recommendation):
                Text(String(localized: "recommendation.eyebrow", defaultValue: "RECOMMENDED", locale: loc))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.positive)
                HStack(spacing: 10) {
                    ProviderIcon(source: recommendation.candidate.icon)
                        .frame(width: 32, height: 32)
                    Text(recommendation.candidate.displayName)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.positive)
                }
                Text(recommendation.reason)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            case .none(let hint):
                Text(String(localized: "recommendation.none.title", defaultValue: "No Recommendation", locale: loc))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(String(
                    localized: "recommendation.none.body",
                    defaultValue: "Every subscription is at its limit right now.",
                    locale: loc
                ))
                .font(.title3)
                .foregroundStyle(.secondary)
                if let hint {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "recommendation.none.recoversSoonest", defaultValue: "Recovers soonest", locale: loc))
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 8) {
                            ProviderIcon(source: hint.candidate.icon)
                                .frame(width: 20, height: 20)
                            Text(hint.candidate.displayName)
                                .font(.body.weight(.semibold))
                            Spacer()
                            Text(hint.reason)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
    }
}
