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

Releases are automated via GitHub Actions: pushing a `v*` tag on `main` builds, signs, notarizes, and publishes a new version.
- A plain tag (`v0.7.1`) ships to everyone on the stable channel.
- A pre-release suffix (`v0.7.1-beta.1`) ships to the beta channel.

The release workflow is defined in [.github/workflows/release.yml](../.github/workflows/release.yml).

### Required Secrets

| Secret | Description |
| --- | --- |
| `APPLE_CERTIFICATE` | Base64 of Developer ID Application `.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | Password for the `.p12` |
| `APPLE_ID` | Apple ID email for notarization |
| `APPLE_PASSWORD` | App-specific password |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APPLE_DEVELOPER_ID_ICLOUD_PROFILE` | Base64 Developer ID provisioning profile |
| `SPARKLE_PUBLIC_KEY` | Base64 EdDSA public key (`SUPublicEDKey`) |
| `SPARKLE_PRIVATE_KEY` | Base64 EdDSA private key to sign DMG |
| `POSTHOG_CLI_API_KEY` | (Optional) PostHog API key for dSYM upload |
| `POSTHOG_CLI_PROJECT_ID` | (Optional) PostHog project ID |

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) and [AGENTS.md](../AGENTS.md) for coding conventions.
