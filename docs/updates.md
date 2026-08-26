# Updates

MaxUsage releases are currently downloaded manually from
[GitHub Releases](https://github.com/1c7/max-usage/releases). Automatic Sparkle updates are disabled
while releases are ad-hoc signed and not notarized by Apple.

## Current release process

- Each `v*` tag builds an ad-hoc signed `MaxUsage-<version>.dmg` in GitHub Actions.
- The workflow publishes that DMG to a non-draft GitHub Release.
- The release notes clearly disclose that the build is not notarized and explain Gatekeeper's first-launch steps.

## Automatic updates

The Sparkle framework remains available in the codebase, but packaged builds omit `SUFeedURL`, so the
updater does not start. Automatic updates can return after MaxUsage has a Developer ID certificate,
Apple notarization, and a MaxUsage-owned signed appcast.
