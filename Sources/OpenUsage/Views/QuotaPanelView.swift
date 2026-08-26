import AppKit
import SwiftUI

/// The two tabs the dashboard reduces to: "which subscription should I use right now" and "how much
/// is left everywhere." Replaces the old customizable provider-card dashboard entirely — see
/// `docs/1- 额度推荐算法.md` / `docs/2- 时间显示算法.md` for the two screens' logic.
enum QuotaPanelTab: Hashable {
    case recommend
    case quota
}

/// The dashboard-only content. Screen switching, panel sizing, fixed bars (top bar / footer), and
/// close/reset behavior stay with `DashboardView`, exactly like the view this replaces.
struct QuotaPanelView: View {
    let container: AppContainer

    @Environment(WidgetDataStore.self) private var dataStore
    @AppStorage(LanguageSetting.key) private var language = LanguageSetting.fallback
    @State private var tab: QuotaPanelTab = .recommend

    var body: some View {
        PopoverScrollView {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let candidates = QuotaCandidateSource.makeCandidates(
                    registry: container.registry,
                    dataStore: dataStore,
                    enablement: container.enablement,
                    orderedProviderIDs: container.layout.orderedProviderIDs()
                )
                VStack(alignment: .leading, spacing: 0) {
                    tabBar
                    // Both tabs stay mounted and measured — only visibility toggles — so the
                    // ZStack's height is always the union of the two, never the active tab alone.
                    // Switching tabs therefore never changes the popover's measured content height,
                    // which is what was driving a visible resize "jump" on every tap (the panel
                    // springs its window height to match whichever tab just became active).
                    ZStack(alignment: .top) {
                        RecommendationTabView(candidates: candidates, now: context.date)
                            .opacity(tab == .recommend ? 1 : 0)
                            .allowsHitTesting(tab == .recommend)
                        QuotaListTabView(candidates: candidates, now: context.date)
                            .opacity(tab == .quota ? 1 : 0)
                            .allowsHitTesting(tab == .quota)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .id(language)
        .environment(\.locale, language.effectiveLocale)
    }

    /// The selected tab gets a filled pill behind its label plus a green underline beneath it — two
    /// independent "this one's active" signals, like a real segmented control, with a full-bleed
    /// divider under the whole row separating chrome from content. Each button's hit target is the
    /// full rectangle (label + pill + generous padding), not just the tightly-cropped pill shape, so
    /// there's a large, obvious click/hover area edge to edge.
    private var tabBar: some View {
        HStack(spacing: 6) {
            tabButton(.recommend, title: AppLocalization.string("quotaPanel.tab.recommend", defaultValue: "Recommended"))
            tabButton(.quota, title: AppLocalization.string("quotaPanel.tab.quota", defaultValue: "Quotas"))
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }

    /// The underline sits flush against the tab row's bottom edge — no breathing room below it — so
    /// there's zero gap between the green bar and the content that starts right under this row.
    private func tabButton(_ target: QuotaPanelTab, title: String) -> some View {
        Button {
            tab = target
        } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tab == target ? Color.primary : Color.secondary)
                    .padding(.top, 10)
                Capsule()
                    .fill(tab == target ? AnyShapeStyle(Theme.positive) : AnyShapeStyle(Color.clear))
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
            .background {
                if tab == target {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.quaternary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            if isHovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}
