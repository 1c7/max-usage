# Phone Sync (LAN)

Phone Sync lets the MaxUsage Android app show a read-only copy of your quotas on your phone. It works
entirely over your local Wi-Fi network — the phone talks directly to this Mac, never to a server MaxUsage
runs, and never needs its own sign-in or provider credentials.

**Base URL:** `http://<this Mac's LAN IP>:6737`

Off by default. Turning on **Allow Phone Sync** in Settings starts a listener reachable from other devices
on the same network and advertises it over Bonjour as `_maxusage._tcp` so the phone can find it without
you typing an IP address.

## Pairing

Because this listener is reachable by anything else on the same Wi-Fi (unlike the loopback-only
[Local HTTP API](local-http-api.md)), every route except `/v1/health` and `/v1/pair` requires a bearer
token naming an already-paired phone.

1. In Settings, click **Add Phone…**. MaxUsage shows a QR code encoding this Mac's current LAN IP, the
   listener's port, and a pairing token good for two minutes.
2. The phone scans the code and exchanges the pairing token for a long-lived bearer token via
   `POST /v1/pair`.
3. The phone stores that token and sends it as `Authorization: Bearer <token>` on every later request.
   No further setup, and no per-provider sign-in, is ever needed on the phone.

Settings lists every paired phone with when it last connected, and lets you remove one — removing it
revokes that phone's token immediately. **Reset All Settings…** turns Phone Sync off and forgets every
paired phone.

Only a hash of each phone's token is ever stored on this Mac; the plaintext token exists only in the
`/v1/pair` response and on the phone itself.

## Routes

### `GET /v1/health`

No auth required. `{"status": "ok", "name": "<this Mac's name>"}` — used by the phone to check
reachability before it has paired.

### `POST /v1/pair`

No auth required (the pairing token itself is the credential, and it's single-use and short-lived).

Body: `{"pairingToken": "...", "deviceName": "..."}`

- **200 OK** — `{"deviceToken": "...", "macName": "..."}`
- **400 Bad Request** — malformed body.
- **403 Forbidden** — the token is wrong, already used, or its two-minute window passed.

### `GET /v1/limits`, `GET /v1/limits/:id`

Requires `Authorization: Bearer <token>`. Same routing, response shape, and `openusage.limits.v1` schema
as the loopback [Local HTTP API](local-http-api.md#get-v1limits) — Phone Sync is a second, authenticated
transport for the same data, not a second format.

- **401 Unauthorized** — missing or unrecognized bearer token.

### Everything else

Same conventions as the loopback API: non-`GET`/`OPTIONS` methods on an existing route return **405**,
unknown routes **404**, and the server backs off busy callers with **503** past 16 concurrent connections.

## What this does and doesn't expose

The phone sees exactly the same usage numbers the menu bar and the loopback API show — no provider
credentials, tokens, or account details are ever served. Nothing is sent anywhere off your local network:
there is no MaxUsage-run server in this feature at all.

The listener binds every network interface on this Mac, not only Wi-Fi, so it also answers on a wired
network or a VPN. It relies on the bearer token — not the interface it's reachable from — to keep the data
private; a home router's NAT keeps it unreachable from the public internet in the common case, but a
network that port-forwards or bridges this Mac's LAN segment could expose it further.
