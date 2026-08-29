# Privacy & Usage Data

MaxUsage is open source and reads credentials that provider tools already keep on your Mac — it never uploads them anywhere, and it only ever talks to each provider's own official API (the same one your CLI already uses). Claude Desktop access is strictly read-only.

## Anonymous usage sharing

Currently disabled — no analytics project is wired up yet, so MaxUsage sends nothing and the toggle for it is hidden from Settings. The app ships with an anonymous, opt-out analytics path already built (small daily summaries — that the app was active, which providers/metrics you enabled, per-provider success/failure counts and error *categories* like "not logged in" or "network", plus crash stack traces) for when that's turned on; it would never include account details, credentials, actual usage values (spend, tokens, limits), error messages, or file paths.

## Other network requests

MaxUsage fetches public model price lists (LiteLLM, models.dev, and the upstream OpenUsage project's pricing feed) about once an hour — plain downloads of public pricing data, unrelated to the usage-sharing toggle. Your own usage logs are parsed and cached locally on your Mac; they're never uploaded anywhere. If you turn on [iCloud Sync](icloud-sync.md), only your own normalized totals sync to your own iCloud container — never credentials or raw logs.
