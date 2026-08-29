import SwiftUI

/// Fixed popover footer chrome: app identity, refresh status, dashboard actions, and copy confirmation.
/// It uses the destination screen so both pages mounted during a slide draw the same footer.
struct PopoverFooter: View {
    let screen: PopoverScreen
    let layout: LayoutStore
    let dataStore: WidgetDataStore
    let horizontalPadding: CGFloat
    let onHeightChange: (PopoverScreen, CGFloat) -> Void

    @ViewBuilder
    var body: some View {
        Group {
            if screen == .customize {
                EmptyView()
            } else {
                HStack(alignment: .center, spacing: 8) {
                    nextUpdateButton
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    HeaderView(screen: screen)
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .barGlass()
        .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in
            onHeightChange(screen, height)
        }
        .overlay(alignment: .top) {
            if screen == .dashboard, layout.shareConfirmation {
                shareCopiedPill
                    .offset(y: -34)
            }
        }
        .animation(Motion.spring, value: layout.shareConfirmation)
        .animation(Motion.spring, value: layout.shareConfirmationTrigger)
    }

    private var shareCopiedPill: some View {
        TransientPill(
            systemImage: "checkmark.circle.fill",
            text: String(localized: "popoverFooter.copiedToClipboard", defaultValue: "Copied to clipboard"),
            tint: Theme.positive,
            trigger: layout.shareConfirmationTrigger
        )
    }

    private var nextUpdateButton: some View {
        Button {
            refreshNow()
        } label: {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 5) {
                    Text(updateStatusText(now: context.date))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if isUpdating {
                        MotionAwareProgressView(controlSize: .mini)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("r", modifiers: .command)
        .hoverTooltip(String(localized: "popoverFooter.refreshTooltip", defaultValue: "Refresh now (⌘R)"))
        .disabled(isUpdating)
    }

    private var isUpdating: Bool {
        !dataStore.refreshingProviderIDs.isEmpty
    }

    private func refreshNow() {
        guard !isUpdating else { return }
        Task { await dataStore.refreshAll(force: true) }
    }

    private func updateStatusText(now: Date) -> String {
        if isUpdating { return String(localized: "popoverFooter.updating", defaultValue: "Updating…") }
        let base = dataStore.lastRefreshAt ?? now
        let remaining = max(0, base.addingTimeInterval(RefreshSetting.interval).timeIntervalSince(now))
        let totalSeconds = Int(remaining.rounded(.up))
        if totalSeconds >= 60 {
            let minutes = Int((Double(totalSeconds) / 60).rounded(.up))
            return String(localized: "popoverFooter.nextUpdateMinutes", defaultValue: "Next update in \(minutes)m")
        }
        return String(localized: "popoverFooter.nextUpdateSeconds", defaultValue: "Next update in \(totalSeconds)s")
    }
}
