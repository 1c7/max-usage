import SwiftUI

/// One metric as a row inside a provider's grouped list container. The provider icon is drawn once in the
/// section header (not per row), so a row shows only the metric. Two layouts:
/// - **Bounded** (`limit != nil`, meter row): one line — name, then a narrow capsule meter (color = pace
///   verdict) immediately followed by the bare percent reading, then the reset time on the trailing edge
///   ("<duration> (<clock time>)", always both readings — no click-to-flip). Collapsed from an earlier
///   three-line label/bar/reading stack so more providers fit the popover without scrolling; the pace
///   verdict (when "Show Pace Prediction" is on) still tints the bar and rides the hover tooltip, it no
///   longer prints inline warning copy.
/// - **Unbounded** (`limit == nil`, text-only row): **no bar**. Label on the left, a single right-aligned
///   descriptive line ("1,503 left") and an optional secondary line ("on-device estimate").
/// Rows size to their own content (variable height). Same `WidgetData` the menu bar uses — only layout differs.
struct WidgetRowView: View {
    let data: WidgetData
    /// Flips the global Used/Left meter style. Supplied where the row has the data store (the
    /// dashboard list); `nil` in static contexts like the drag-reorder preview, where the meter
    /// cluster stays plain (not a button).
    var onToggleMeterStyle: (() -> Void)?
    /// True when this text-only row sits directly under another text-only row. Rows don't know
    /// their neighbors — the list supplies it — and both densities use it to pull consecutive
    /// one-liners into a single cluster (Compact a step harder).
    var condensedTop: Bool = false

    @AppStorage(DensitySetting.key) private var density = DensitySetting.regular
    @Environment(\.reduceAnimations) private var reduceAnimations
    @State private var modelHover = HoverPopoverState()
    /// Backs the resets popover's claim flow; `nil` outside the live dashboard (previews, share
    /// renders), which renders the timeline read-only.
    @Environment(\.codexResetClaim) private var codexResetClaim
    /// Party easter egg: fill meter bars with the party gradient instead of the severity color. Off by
    /// default everywhere else.
    @Environment(\.popoverPartyMode) private var partyMode

    /// Both row fonts come from the density setting: point sizes — not just padding — are what make
    /// Compact read as a denser mode. The sizes are explicit because semantic
    /// `.headline.weight(.regular)` does not match `.headline` on macOS, and `minimumScaleFactor`
    /// was shrinking only the trailing value.
    private var labelFont: Font {
        .system(size: density.labelPointSize, weight: .semibold)
    }

    private var supportingFont: Font {
        .system(size: density.supportingPointSize, weight: .regular)
    }

    var body: some View {
        // A row with a concrete reset date derives time-sensitive state (reset countdown, pace marker,
        // "Runs out in …") from the current clock, so it re-renders on a 30s tick — the cadence the
        // original app uses — instead of waiting for the next data refresh. TimelineView only schedules
        // ticks while the popover is actually visible. Rows without a reset date are static.
        Group {
            if data.resetsAt != nil || !data.expiriesAt.isEmpty {
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    rowContent
                }
            } else {
                rowContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        // Bar rows are multi-line and earn breathing room; single-line text rows (Today / Yesterday /
        // Last 30 Days) stay tighter so consecutive ones read as a cluster, not evenly-spaced
        // full-height rows. This differentiation — not the fonts — is what kills the "jumpy" rhythm.
        // All values come from the global density setting; a text row pulls up against a preceding
        // text row (`condensedTop`) in both densities.
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
    }

    private var topPadding: CGFloat {
        condensedTop ? density.condensedTextRowTopPadding : density.textRowPadding
    }

    private var bottomPadding: CGFloat {
        density.textRowPadding
    }

    @ViewBuilder
    private var rowContent: some View {
        if data.isChart, data.hasData {
            // The sparkline owns its own label + bars; a chart with no real points falls through to the
            // unbounded "No data" row below (and so descriptor template data never leaks here).
            UsageSparkline(data: data)
        } else if data.isBounded {
            boundedRow
        } else {
            unboundedRow
        }
    }

    /// Bounded: one line — name, the narrow meter cluster (bar + bare percent), and the reset time
    /// trailing. The old label/bar/reading stack is now one row; the pace verdict still tints the bar
    /// (and rides its hover tooltip when "Show Pace Prediction" is on) but no longer prints inline
    /// warning copy — there's no room for it, and most usage patterns don't want it anyway.
    private var boundedRow: some View {
        let state = data.meterState()
        return HStack(spacing: 8) {
            Text(data.title)
                .font(labelFont)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .layoutPriority(1)
            meterCluster(state)
            Spacer(minLength: 8)
            trailingContext
        }
    }

    /// The narrow bar immediately followed by its bare percent reading — one visual unit, click to
    /// flip the global Used/Left meter style (the compact row's counterpart to the old headline
    /// toggle). Hovering surfaces the pace verdict projection when there is one, otherwise the
    /// opposite Used/Left reading.
    @ViewBuilder
    private func meterCluster(_ state: WidgetData.MeterState) -> some View {
        let cluster = HStack(spacing: 6) {
            meter(state)
                .frame(width: Self.compactMeterWidth)
            Text(percentText)
                .font(supportingFont)
                .foregroundStyle(.primary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        if data.hasMeterStyleToggle, let onToggleMeterStyle {
            Button(action: onToggleMeterStyle) { cluster }
                .buttonStyle(.plain)
                .hoverTooltip(clusterTooltip(state))
        } else {
            cluster.hoverTooltip(clusterTooltip(state))
        }
    }

    /// Fixed width for the compact bar — narrow enough that name, meter, and reset time share one
    /// line even on the smaller Compact density.
    private static let compactMeterWidth: CGFloat = 44

    /// Bare percent reading (no "left"/"used" word — the row is too tight for it); `data.fraction`
    /// already reflects the global Used/Left display mode, so the number alone still flips correctly.
    private var percentText: String {
        let percent = Int((data.fraction * 100).rounded())
        return "\(percent)%"
    }

    /// Bar/copy color for a severity, or the inactive gray when there's none (the no-data track).
    private func severityColor(_ severity: WidgetData.MeterSeverity?) -> AnyShapeStyle {
        severity.map(Theme.meterFill) ?? AnyShapeStyle(Color.secondary)
    }

    /// Hover explanation for the meter cluster: the pace verdict projection when "Show Pace
    /// Prediction" surfaces one (`state.tooltip`), otherwise the opposite Used/Left reading.
    private func clusterTooltip(_ state: WidgetData.MeterState) -> String? {
        state.tooltip ?? data.meterStyleTooltip
    }

    /// Reset time on the trailing edge, plain text — the combined "<duration> (<clock time>)" phrase
    /// already carries both the countdown and the exact time, so there's nothing left to click-to-flip.
    @ViewBuilder
    private var trailingContext: some View {
        if let text = data.boundedTrailingText() {
            Text(text)
                .font(supportingFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .hoverTooltip(data.resetTooltip())
        }
    }

    /// Unbounded: no bar. Label on the left, with a single right-aligned descriptive line ("1,503 left")
    /// and an optional secondary line ("on-device estimate") beneath it.
    private var unboundedRow: some View {
        unboundedRowContent
            .onChange(of: data.modelBreakdown) { _, _ in modelHover.dismiss() }
            // A refresh can replace the reset credits (count and expiries) while the popover is open;
            // drop it so it never lingers over a stale timeline — except while the claim flow has the
            // popover pinned: the claim's own forced refresh is what changes the credits, and dismissing
            // on it would close the popover before the claim's result banner ever renders. The pinned
            // popover re-renders from the new data instead (the detail view reconciles its own state).
            .onChange(of: data.expiriesAt) { _, _ in
                if !modelHover.isPinned { modelHover.dismiss() }
            }
            .onDisappear { modelHover.dismiss() }
    }

    /// The value column reveals the model breakdown on hover, so it lights up under the pointer the way
    /// a Finder / System Settings list row does — the native cue that "this is a target." Lit the moment
    /// the pointer arrives (`overInline`, before the reveal dwell) and held lit while the popover is open,
    /// so the value reads as the popover's source. Both flags live on `modelHover`, so the panel's close
    /// path (`dismissAll`) clears the highlight even though this view's state survives `orderOut`. Only
    /// rows that actually have a breakdown light up.
    private var showValueHighlight: Bool {
        hasHoverPopover && (modelHover.overInline || modelHover.isPresented)
    }

    /// Whether the value column reveals a hover popover: the model breakdown on spend rows, or the
    /// resets timeline on the Codex rate-limit-resets row. One `modelHover` coordinator drives both — a
    /// row is only ever one kind — so lighting the value and anchoring the popover share the spend
    /// row's machinery. The resets row qualifies even at "0 available" (empty `expiriesAt`), so its
    /// empty-state popover stays reachable — but only with real data: a "No data" tile must not open a
    /// popover that reads as "zero credits" (`hasModelBreakdown` already carries its own `hasData`).
    private var hasHoverPopover: Bool {
        data.hasModelBreakdown || (data.showsResetExpiries && data.hasData)
    }

    private var unboundedRowContent: some View {
        HStack(alignment: .center, spacing: 10) {
            labelColumn
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    expiryStatusDot
                    Text(data.unboundedDetail)
                        .font(supportingFont)
                        .foregroundStyle(.primary) // the value is the row's payload — match the bounded headline
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        // Hover target is the value text itself, not the whole row — the same
                        // per-element pattern the bounded row uses for "x left" and "Resets in …". Reveals
                        // the exact figures the compact value shortens, or "No usage in this period" on a
                        // zero row; nil (no tooltip) on a small, already-full, non-zero row. Suppressed
                        // when the model-breakdown popover is wired up — a text bubble and a popover
                        // fighting over the same hover reads as two competing surfaces, and the panel's
                        // per-model tooltips carry the exact figures instead. The resets row likewise
                        // drops its tooltip — the timeline popover replaces it.
                        .hoverTooltip(hasHoverPopover ? nil : data.unboundedValueTooltip)
                }
                if let subtitle = data.unboundedSubtitle {
                    // Secondary, not tertiary: the subtitle is informational ("on-device estimate"),
                    // and tertiary is reserved for inactive content on glass.
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .multilineTextAlignment(.trailing)
            // A quaternary chip behind the value — the app's subtle-fill token, in the shared 6pt
            // continuous corner — signals the value is interactive before the breakdown even opens.
            // Negative-inset so it hugs the figure without changing the row's height (the text-row
            // rhythm that clusters Today / Yesterday / Last 30 Days must not shift), and a quick
            // opacity fade in/out matches macOS hover states.
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.quaternary)
                    .padding(.horizontal, -7)
                    .padding(.vertical, -4)
                    .opacity(showValueHighlight ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.12), value: showValueHighlight)
            // Both the hover trigger and the popover anchor live on the value column, not the whole
            // row: hovering the label (or empty gap) shouldn't reveal the breakdown — only the figure
            // it explains should — and the arrow then centers on that figure, matching the trend
            // popover's anchoring off the sparkline strip.
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard hasHoverPopover else {
                    modelHover.dismiss()
                    return
                }
                if case .active = phase {
                    modelHover.inlineHover(true)
                } else {
                    modelHover.inlineHover(false)
                }
            }
            .motionAwareHoverPopover(
                isPresented: Binding(
                    get: { hasHoverPopover && modelHover.isPresented },
                    // A click-outside dismiss removes the detail view without an `.ended` hover event,
                    // so a plain assignment would strand `overDetail == true` and block future hides.
                    set: { if !$0 { modelHover.dismiss() } }
                ),
                reduceAnimations: reduceAnimations
            ) {
                if let breakdown = data.modelBreakdown {
                    ModelUsageDetail(title: data.title, breakdown: breakdown) { inside in
                        modelHover.detailHover(inside)
                    }
                } else if data.showsResetExpiries {
                    RateLimitResetsDetail(
                        count: data.resetCreditCount, expiries: data.expiriesAt,
                        onHoverChange: { inside in modelHover.detailHover(inside) },
                        onPinChange: { pinned in modelHover.setPinned(pinned) },
                        // Rows with reset expiries are Codex-only today, so the Codex claim service is
                        // the right backing; absent from the environment (previews, share renders) the
                        // timeline is read-only.
                        claim: codexResetClaim.map { service in
                            { expiry, redeemRequestID in
                                await service.claim(creditExpiringAt: expiry, redeemRequestID: redeemRequestID)
                            }
                        }
                    )
                }
            }
        }
    }

    /// Small blue/yellow/red status dot shown just before the value when the row carries reset-credit
    /// expiries — colored by the soonest expiry. The per-credit detail (which credits, expiring when)
    /// lives in the resets popover the value column now reveals on hover, so the dot carries no tooltip
    /// of its own. Renders nothing when no credit is available (an empty `expiriesAt`).
    @ViewBuilder
    private var expiryStatusDot: some View {
        if let severity = data.expirySeverity() {
            Circle()
                .fill(severityColor(severity))
                .frame(width: 6, height: 6)
                .accessibilityLabel(expiryStatusAccessibilityLabel(severity))
        }
    }

    private func expiryStatusAccessibilityLabel(_ severity: WidgetData.MeterSeverity) -> String {
        switch severity {
        case .normal:
            return String(
                localized: "widgetRow.expiryStatus.normal",
                defaultValue: "Reset credits expire in more than 7 days"
            )
        case .warning:
            return String(localized: "widgetRow.expiryStatus.warning", defaultValue: "A reset credit expires within 7 days")
        case .critical:
            return String(
                localized: "widgetRow.expiryStatus.critical",
                defaultValue: "A reset credit expires within 48 hours"
            )
        }
    }

    private var labelColumn: some View {
        HStack(spacing: 4) {
            Text(data.title)
                // Same point size as the trailing value so the single-line row reads tight;
                // semibold alone keeps the name/value hierarchy.
                .font(.system(size: density.supportingPointSize, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            unknownModelWarningIcon
        }
    }

    /// Amber warning triangle shown just after a spend tile's label (Today / Yesterday / Last 30 Days)
    /// when the period used a model the pricing manifest can't price, so its cost is incomplete. Hovering
    /// lists the unknown model names. Renders nothing otherwise.
    @ViewBuilder
    private var unknownModelWarningIcon: some View {
        if data.hasUnknownModels {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: density.supportingPointSize - 1))
                .foregroundStyle(severityColor(.warning))
                .hoverTooltip(data.unknownModelTooltip)
                .accessibilityLabel("This period used a model with unknown pricing")
        }
    }

    /// Full-width capsule meter — the Tahoe-era level-indicator form (capsule, full-height
    /// leading-anchored fill, like the redesigned Slider / Control Center). Deliberately NOT the
    /// native linear `Gauge`/`ProgressView`, which Tahoe left as the thin legacy bar. The fill is
    /// a flat **system color** carrying the pace verdict (blue = well within limits, yellow =
    /// projected to land inside the last 10%, red = projected to run out; `Theme.meterFill` /
    /// `MeterState.severity`) at full strength on the opaque popover surface; the earlier
    /// provider-brand gradient was removed deliberately so the bar's color always reads as state.
    /// Empty + colorless without data. A thin tick marks the even-pace line — where usage would sit
    /// if it burned evenly across the reset window — on yellow and red bars always, and on blue when
    /// "always show pacing" is on. The tick rides in an overlay so it pokes out top and bottom without
    /// changing the bar's height. Hovering shows the pace projection (`MeterState.tooltip`).
    private func meter(_ state: WidgetData.MeterState) -> some View {
        let tick = data.paceTick(for: state)
        return GeometryReader { proxy in
            // Track + fill define the bar's height; the tick rides in an `.overlay` so its taller frame
            // pokes out top and bottom without stretching the capsules. (As a ZStack sibling it grew the
            // stack and the flexible capsules stretched with it, so a tick'd bar read as a thicker bar.)
            ZStack(alignment: .leading) {
                // Semantic quaternary fill (not an opacity-faded color) so the track stays vibrant
                // on glass and adapts to Increase Contrast / Reduce Transparency.
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(partyMode ? PartyMode.meterFill : severityColor(state.severity))
                    .frame(width: fillWidth(track: proxy.size.width))
            }
            .overlay(alignment: .leading) {
                if let tick {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.primary.opacity(0.55))
                        .frame(width: Self.paceTickWidth, height: density.meterHeight + Self.paceTickOverhang)
                        .offset(x: paceTickOffset(track: proxy.size.width, fraction: tick))
                }
            }
        }
        .frame(height: density.meterHeight)
        .animation(Motion.spring, value: data.fraction)
        .accessibilityHidden(true)
        .hoverTooltip(state.tooltip)
    }

    private static let paceTickWidth: CGFloat = 2
    /// How much taller than the bar the tick is, so it pokes out slightly above and below (half each
    /// end). The bar itself stays at `meterHeight` regardless — the tick lives in an overlay.
    private static let paceTickOverhang: CGFloat = 4

    /// Leading offset that centers the tick on its fraction, clamped so the tick never pokes past
    /// either rounded end of the track.
    private func paceTickOffset(track: CGFloat, fraction: Double) -> CGFloat {
        let centered = track * fraction - Self.paceTickWidth / 2
        return min(max(centered, 0), max(track - Self.paceTickWidth, 0))
    }

    /// Fill width with a minimum-visible rule: any non-zero fraction renders at least a full circle
    /// (width = bar height) so 1–2% never squashes into an invisible sliver — the same idea as the
    /// menu-bar bars' minimum fill.
    private func fillWidth(track: CGFloat) -> CGFloat {
        guard data.hasData, data.fraction > 0 else { return 0 }
        return max(density.meterHeight, track * data.fraction)
    }
}
