# Menu Bar

The menu bar icon always shows exactly one thing: whichever subscription the [Recommended tab](dashboard.md#recommended) currently points at — its icon and weekly-quota-remaining percentage. It follows the same tiered-EDF pick as the popover, so the tray and the popover's Recommended tab never disagree.

When nothing currently qualifies for a recommendation (see [Dashboard § Recommended](dashboard.md#recommended) for when that happens), the tray falls back to the plain OpenUsage icon.

## Right-clicking the icon

Right-click (or control-click) the menu bar icon for a quick menu with **Settings** and **Quit**. Left-click opens the popover as usual.

## Styles

Settings → Appearance → Icon Style:

- **Text** — the recommended provider's icon plus its weekly-remaining percentage.
- **Bars** — the same pick as a compact single-bar glyph instead of text.

## Hiding usage while screen sharing

Settings → Privacy → **Hide From Screen Share** (off by default). While your screen is being shared or recorded — a Zoom/Meet/Teams share, a screen recording, macOS Screen Sharing — the strip is replaced with the OpenUsage icon and wordmark, so quota numbers never show up in front of an audience. The moment the capture ends, the recommendation comes right back. Captures you start yourself (a screen recording, for example) count too, so those get the wordmark as well.

Detection rides the system's own "an app is capturing the screen" signal — the same one that lights the capture indicator in the menu bar — checked the instant it changes and re-checked every few seconds while the setting is on.

Normally:

![The menu bar strip showing usage values](assets/menu-bar-privacy-idle.png)

While the screen is shared or recorded:

![The menu bar strip concealed behind the OpenUsage wordmark](assets/menu-bar-privacy-sharing.png)
