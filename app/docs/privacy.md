# Privacy & Usage Data

MaxUsage is open source and reads credentials that provider tools already keep on your Mac — it never uploads them anywhere, and it only ever talks to each provider's own official API (the same one your CLI already uses). Claude Desktop access is strictly read-only.

## Anonymous usage sharing

On by default; turn off anytime in **Settings → Privacy → Share Anonymous Usage**. When on, MaxUsage sends small daily summaries — that the app was active, which providers/metrics you enabled, and per-provider success/failure counts and error *categories* (e.g. "not logged in", "network") — plus crash stack traces if MaxUsage crashes. A random, non-identifying ID counts daily active users.

**Never shared:** account details, credentials, actual usage values (spend, tokens, limits), error messages, or file paths. Turn the toggle off and nothing further is sent.

## Other network requests

MaxUsage fetches public model price lists (LiteLLM, models.dev, and the upstream OpenUsage project's pricing feed) about once an hour — plain downloads of public pricing data, unrelated to the usage-sharing toggle. Your own usage logs are parsed and cached locally on your Mac; they're never uploaded anywhere. If you turn on [iCloud Sync](icloud-sync.md), only your own normalized totals sync to your own iCloud container — never credentials or raw logs.
