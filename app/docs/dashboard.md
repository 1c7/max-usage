# Dashboard

The popover that opens from the menu bar icon. Two tabs answer the two questions MaxUsage exists for:

- **Recommended** — of the subscriptions you can use right now, which one should you use?
- **Quotas** — how much is left on every one of them?

## Recommended

A single answer: the name of the subscription you should reach for, and a one-line reason (its weekly quota level and when it resets, e.g. "Weekly quota still has 74%, resets in 2 days").

The pick follows a strict EDF rule (see `docs/1- 额度推荐算法.md` for the full spec):

1. **Gate** — a subscription only qualifies if it currently has weekly quota left *and* its short window (a rolling 5-hour session, or a daily cap for Devin) isn't exhausted. A subscription failing either check is dropped, not just deprioritized.
2. **Earliest reset** — among qualifying subscriptions, the exact earliest weekly reset wins, regardless of how much a later-resetting subscription has left.
3. **Tie-break** — only subscriptions with the exact same reset time compare weekly quota remaining; the larger remainder wins.

**No Recommendation** shows instead when nothing currently qualifies — every subscription's weekly quota is spent, or every one's short window is currently exhausted. When the block is only the short window, the screen also names whichever subscription's short window frees up soonest, as a hint for what to check back on.

With only one subscription configured, this tab still applies the same gate: it tells you whether that subscription is usable right now, never just echoing it back unconditionally.

## Quotas

Every eligible subscription side by side, each with:

- A reset label (`docs/2- 时间显示算法.md`'s rule: minutes under an hour, whole hours under a day, "Resets tomorrow" for 24–48h, whole days beyond that — one unit, never combined).
- A **Weekly** bar and percentage.
- A short-window bar (labeled **5-Hour** or **Daily**) and percentage, when the provider reports one.

Providers follow the order saved in Customize. A provider whose weekly quota is exhausted moves to a
temporary group at the bottom without changing that saved order, then returns to its saved position after
the reset. Exhausted rows replace the empty 0% meter with **Weekly quota used up** and show the reset as
an exact localized date and time.

Bar color is a plain level read (not a burn-rate projection): blue with more than half left, yellow at 50% or less, red at 20% or less.

## Which subscriptions appear

Only providers that report a percent-bounded weekly-style quota participate: Claude, Codex, OpenCode, Z.ai, Antigravity (as two independent entries — its Gemini pool and its Claude pool — since they're separate quotas), Devin, and Grok. A provider only appears once you've turned it on in Customize and it has real usage data. Cursor, Copilot, and OpenRouter meter dollars or credits instead of a rate-limited percentage, so they don't fit this model and aren't shown here.

## Footer

Unchanged from before: the app version and a live "Next update in …" countdown on the left (click it, or press **⌘R**, to refresh now); an **Options** menu on the right holding **Customize**, **Settings**, **Check for Updates…**, **About MaxUsage**, and **Quit MaxUsage**.

## Customize / Settings

Reached from the footer's **Options** menu (or press **Return**). Customize still controls which providers are turned on — that's what feeds both tabs above — plus the metrics pinned to the menu-bar strip itself; it no longer affects what the popover's Recommended/Quotas tabs show beyond the on/off switch. See [Which Providers Are On](provider-enablement.md) and [Settings](settings.md).

## Keyboard

| Key | Action |
|---|---|
| Return | From the dashboard, open Customize; from a provider detail, return to the provider list; from the provider list or Settings, return to the dashboard |
| Esc | From a provider detail, return to the provider list; from the provider list or Settings, return to the dashboard; from the dashboard, close the popover |
| ⌘R | Refresh now from the dashboard or Settings (skips the cache) |
| ⌘, | Open / close Settings (in the popover) |

A global shortcut (recorded in Settings) toggles the popover from anywhere.
