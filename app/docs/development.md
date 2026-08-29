# Development & Releases

Guidelines for building, testing, and releasing MaxUsage.

## Requirements

- macOS 15 (Sequoia) or later
- Swift 6.0+ toolchain
- Universal binary runs natively on both Apple Silicon and Intel Macs

## Building & Testing

```sh
# Debug build
swift build

# Run test suite
swift test

# Build and launch local dev app from dist/ (no install needed)
./script/build_and_run.sh
```

## Architecture Overview

MaxUsage is a SwiftPM package with a shared core module and native macOS menu-bar UI (SwiftUI hosted inside an AppKit-owned `NSStatusItem` + custom `NSPanel`).

For full details on stores, providers, caching, and AppKit integration, see [Architecture](architecture.md).

## Releasing

Releases are automated via GitHub Actions: pushing a `v*` tag on `main` builds an ad-hoc signed DMG and publishes a new version.
- A plain tag (`v0.7.1`) ships to everyone on the stable channel.
- A pre-release suffix (`v0.7.1-beta.1`) ships to the beta channel.

The release workflow is defined in [.github/workflows/release.yml](../../.github/workflows/release.yml).

A `TAP_TOKEN` repository secret (a PAT with push access to the Homebrew tap repo) is required for the
tap-update step; no other release secrets are needed. These builds are not notarized, so release notes
must keep the Gatekeeper installation notice visible. Developer ID signing, notarization, and automatic
Sparkle updates can be restored together after the project joins the Apple Developer Program.

## Contributing

See [CONTRIBUTING.md](../../.github/CONTRIBUTING.md) and [AGENTS.md](../AGENTS.md) for coding conventions.
