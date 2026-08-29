# iCloud Sync

**Sync Across Macs** is off by default. When it is on, each Mac writes one versioned MaxUsage history
file to the app's private iCloud container and reads the files written by other Macs signed into the same
iCloud account. A random device ID is kept in the login Keychain so the same Mac continues updating its
existing file after app preferences are reset or the app is reinstalled. There is no folder picker,
pairing code, or separate account.

The file contains normalized daily tokens and spend, model totals, and unknown-model names for sources
that are local to one Mac: Claude, Codex, Grok, and OpenCode. It does not contain credentials, account
limits, raw logs, or provider responses. Cursor's history is already account-wide, so it stays local and
is never added across Macs. Disabling a provider immediately removes its peer contributions from the
combined view and omits it from this Mac's next iCloud write, while its local cached snapshot remains.

MaxUsage combines the valid files in memory and rebuilds Today, Yesterday, Last 30 Days, Usage Trend,
unknown-model warnings, and model breakdowns. The same combined spend rows feed the dashboard, Total
Spend, menu-bar pins, share cards, and the local HTTP API. Both `/v1/usage` and `/v1/limits` read the
same rendered snapshots; the former is the deprecated UI-oriented format and the latter is the
normalized format. Quotas, plans, balances, and provider errors remain this Mac's own values inside
those snapshots. Rows retained in an older peer file are ignored once they fall outside the same
calendar window used by the local history scanners.

This Mac updates its file after a five-minute refresh batch, a manual refresh, or a provider enablement
change. iCloud delivery is eventually consistent, so another Mac can take longer than five minutes to
receive it, especially while offline. Downloaded changes reload immediately when macOS reports them.

Settings lists each valid device file with the time that Mac generated it. To remove a Mac from the
combined summary, turn sync off on that Mac; this deletes its file from iCloud. Turning sync off also
stops that Mac from reading peers and immediately returns every surface there to local-only spend.
Malformed files are ignored and reported in Settings and the app log.

## Development and release setup

Apple requires the iCloud container assignment to be present in the provisioning profile embedded in
the app. MaxUsage uses separate resources so development builds cannot write production history:

- `com.1c7.maxusage.dev` uses `iCloud.com.1c7.maxusage.dev` when a matching development profile exists.
- The current ad-hoc release does not include iCloud entitlements.

Create a `MAC_APP_DEVELOPMENT` profile that includes every registered development Mac and a
`MAC_APP_DIRECT` profile for releases. Install the development profile on each included Mac. The
development build automatically selects the newest non-expired profile matching the development
bundle and iCloud container from Xcode's current profile directory or the legacy MobileDevice
directory:

```bash
./script/build_and_run.sh
```

Set `ICLOUD_PROVISIONING_PROFILE=/path/to/profile.mobileprovision` only when you need to override
that automatic selection. An explicit missing path fails the build instead of silently producing an
app without iCloud access.

**Not yet implemented:** the release workflow (`.github/workflows/release.yml`) has no provisioning-profile
or iCloud-entitlement step today — this is why "the current ad-hoc release does not include iCloud
entitlements" above. Wiring a `MAC_APP_DIRECT` profile into CI (via a base64-encoded Actions secret) is
the planned approach once the project has an Apple Developer ID; keep the original provisioning profiles
and signing `.p12` in a password manager, never in the repository, when that lands.

To inspect the actual history written by a running build, find the file first and only call `jq` when a
file exists:

```bash
file=$(find "$HOME/Library/Mobile Documents" \
  -type f -path '*maxusage*/OpenUsage/History/v1/*.json' -print -quit)

if [[ -n "$file" ]]; then
  jq . "$file"
else
  echo "No MaxUsage iCloud history file found"
fi
```

No file is expected when sync is off, the app is signed without the matching profile, or the first
write has not completed. The Settings error and app log distinguish those cases; the spinner only
appears while an iCloud read or write is actually in progress.
