# LumaRush Nakama Backend

This folder provides a local Nakama backend for LumaRush with:

- User authentication hooks (custom + device).
- Per-user high score tracking.
- Global high score leaderboard.
- Optional Terapixel platform integration webhooks.
- Terapixel platform proxy RPCs (B1 pattern: client -> Nakama -> platform).

## Files

- `backend/nakama/docker-compose.yml`: Local CockroachDB + Nakama stack.
- `backend/nakama/local.yml`: Nakama runtime config.
- `backend/nakama/modules/lumarush.js`: Runtime module with hooks and RPCs.

## Run Locally

1. `cd backend/nakama`
2. Start platform dependencies in another terminal:
   - `cd c:\code\terapixel-platform`
   - `SESSION_SECRET=<your-secret> CRAZYGAMES_EXPECTED_AUDIENCE=lumarush npm run start:identity`
   - `SESSION_SECRET=<your-secret> npm run start:iap`
3. `docker compose up --build`

Nakama ports:

- API: `http://localhost:7350`
- Console: `http://localhost:7351` (`admin` / `adminpassword`)

## Runtime Environment Variables

Set these in `backend/nakama/local.yml` under `runtime.env`:

- `TPX_PLATFORM_AUTH_URL`: Optional URL called before custom/device auth. Non-2xx blocks auth.
- `TPX_PLATFORM_EVENT_URL`: Optional URL called on auth success and score submit.
- `TPX_PLATFORM_API_KEY`: Optional bearer token for both Terapixel endpoints.
- `TPX_PLATFORM_IDENTITY_NAKAMA_AUTH_URL`: `POST /v1/auth/nakama`
- `TPX_PLATFORM_IAP_VERIFY_URL`: `POST /v1/iap/verify`
- `TPX_PLATFORM_IAP_ENTITLEMENTS_URL`: `GET /v1/iap/entitlements`
- `TPX_PLATFORM_IAP_COINS_ADJUST_URL`: `POST /v1/iap/coins/adjust`
- `TPX_PLATFORM_ACCOUNT_MERGE_CODE_URL`: `POST /v1/account/merge/code`
- `TPX_PLATFORM_ACCOUNT_MERGE_REDEEM_URL`: `POST /v1/account/merge/redeem`
- `TPX_PLATFORM_MAGIC_LINK_START_URL`: `POST /v1/account/magic-link/start`
- `TPX_PLATFORM_MAGIC_LINK_COMPLETE_URL`: `POST /v1/account/magic-link/complete` (optional/manual fallback)
- `TPX_PLATFORM_USERNAME_VALIDATE_URL`: `POST /v1/identity/internal/username/validate` (identity moderation source of truth)
- `TPX_PLATFORM_INTERNAL_KEY`: admin key used for internal platform endpoints (maps to platform `INTERNAL_SERVICE_KEY`)
- `TPX_MAGIC_LINK_NOTIFY_SECRET`: shared secret for platform callback RPC `tpx_account_magic_link_notify`
- `TPX_USERNAME_CHANGE_COST_COINS`: coin price after first free username set (default `300`)
- `TPX_USERNAME_BLOCKLIST`: optional blocked username tokens as CSV or JSON array. Example CSV: `admin,moderator,badword`; JSON: `["admin","moderator","badword"]`
- `TPX_USERNAME_MODERATION_FAIL_OPEN`: `true|false` fallback mode when platform moderation endpoint is unavailable (default `false`).
- `TPX_USERNAME_CHANGE_COOLDOWN_SECONDS`: cooldown between username changes (default `300`).
- `TPX_USERNAME_CHANGE_MAX_PER_DAY`: max successful username changes per rolling day window (default `3`).
- `TPX_GAME_ID`: game id sent to identity exchange (`lumarush` default)
- `TPX_EXPORT_TARGET`: `ios`|`android`|`poki`|`crazygames`|`web` (used for provider selection; default `web`)
- `TPX_HTTP_TIMEOUT_MS`: HTTP timeout for Terapixel calls (default `5000`).
- `LUMARUSH_LEADERBOARD_ID`: Leaderboard ID (default `lumarush_high_scores`).

## RPC Contract

### `tpx_submit_score`

Authenticated user only.

Request:

```json
{
  "score": 1000,
  "subscore": 12,
  "metadata": { "track": "neo_city" }
}
```

Response:

```json
{
  "leaderboardId": "lumarush_high_scores",
  "record": { "...": "nakama leaderboard record" }
}
```

### `tpx_get_my_high_score`

Authenticated user only.

Request: `{}` or empty payload.

Response:

```json
{
  "leaderboardId": "lumarush_high_scores",
  "highScore": { "...": "owner leaderboard record or null" },
  "playerStats": {
    "bestScore": 1000,
    "bestSubscore": 12,
    "rank": 5
  }
}
```

### `tpx_list_leaderboard`

Public list.

Request:

```json
{
  "limit": 25,
  "cursor": ""
}
```

Response:

```json
{
  "leaderboardId": "lumarush_high_scores",
  "records": [],
  "nextCursor": "",
  "prevCursor": "",
  "rankCount": 0
}
```

## Auth for Clients

Clients should authenticate with Nakama normally (device/custom). This module adds:

- Optional pre-auth verification against `TPX_PLATFORM_AUTH_URL`.
- Auth success event emission to `TPX_PLATFORM_EVENT_URL`.

If the Terapixel auth URL is unset, Nakama auth proceeds without external verification.

## Platform Proxy RPCs

- `tpx_iap_purchase_start`: proxies purchase verification to platform.
- `tpx_iap_get_entitlements`: returns latest platform entitlements.
- `tpx_iap_sync_entitlements`: forces platform entitlement refresh.
- `tpx_account_merge_code`: creates pairing code for current user.
- `tpx_account_merge_redeem`: redeems pairing code and merges account into primary.
- `tpx_account_magic_link_status`: reads completion state pushed from platform.
- `tpx_account_magic_link_notify`: platform callback endpoint (shared-secret protected; enforces `game_id` when provided).
- `tpx_account_username_status`: returns current username + free/paid rename policy.
- `tpx_account_update_username`: validates and updates username (first change free, then coins).

## Deploy on Render (fallback)

Render is decommissioned as the primary hosting path. Keep this section for disaster recovery only.
To re-enable GitHub-triggered fallback deploys, set repository/environment variable `RENDER_ENABLED=true`
and restore the required Render secrets (`RENDER_API_KEY`, `RENDER_SERVICE_IDS`).

This repo now includes a Render Blueprint at `render.yaml` for a managed Postgres database plus a Docker-based Nakama web service.

1. In Render, create a new Blueprint deployment from this repo.
2. Confirm the `lumarush-nakama` service and `lumarush-nakama-db` database are detected.
3. Set secrets that are marked `sync: false`:
   - `TPX_PLATFORM_AUTH_URL` (optional)
   - `TPX_PLATFORM_EVENT_URL` (optional)
   - `TPX_PLATFORM_API_KEY` (optional)
   - `NAKAMA_CONSOLE_PASSWORD` (recommended)
4. Deploy.

The Render startup script (`backend/nakama/render/start.sh`) runs migrations, starts Nakama on internal ports, and fronts it with nginx on Render's public `PORT`.

On Render (fallback only):

- API/Client endpoints: `https://<your-service>.onrender.com/`
- Console: `https://<your-service>.onrender.com/console/`

## Deploy on Cloud Run (primary)

Cloud Run deployment scaffolding is available under `backend/nakama/cloudrun/`.

Active runtime endpoints:
- Production API/client: `https://terapixel.games/nakama/lumarush/`
- Production console (Access-gated): `https://terapixel.games/nakama/lumarush/console`
- Staging origin service: `https://lumarush-nakama-r42ojz43uq-uc.a.run.app`

1. Build and push image with `backend/nakama/Dockerfile.render`.
2. Create the required Secret Manager secrets (`nakama-db-address`, `nakama-server-key`, etc.).
3. Render placeholders in `backend/nakama/cloudrun/service.template.yaml`.
4. Apply with `gcloud run services replace`.

Use `backend/nakama/cloudrun/README.md` for exact commands.

## Authenticated Nakama identity exchange

The companion platform hardening requires a dedicated backend credential for
`POST /v1/auth/nakama`. Set server-only `TPX_NAKAMA_EXCHANGE_KEY` to the approved
credential matching this environment's `lumarush` entry in the gateway's
`NAKAMA_EXCHANGE_KEYS_JSON`. Use at least 32 characters from `A-Z`, `a-z`, `0-9`,
`_`, and `-`; no credential is supplied here. Do not reuse platform admin/API keys,
Nakama server/HTTP keys, or another game's/environment's credential. Never put this
value in Godot exports, client payloads, checked-in YAML, command tracing, or logs.
Missing or invalid configuration disables exchange before any outbound request.

Both `modules/lumarush.js` and the template-derived `modules/index.js` now require
an authenticated nonblank string `ctx.userId`. The template RPC
`platform_auth_exchange` ignores payload identity/game/credential fields and uses
only `ctx.userId`, server `GAME_ID`, and the configured credential. The active
LumaRush path uses server `TPX_GAME_ID` (default `lumarush`). Only identity exchange
requests get `x-nakama-exchange-key`; other platform requests do not receive it.

Loading analysis: `local.yml` and generated `render/start.sh` runtime config both
select `js_entrypoint: "lumarush.js"`. `Dockerfile.render` copies the modules and
uses that startup script; Cloud Run reuses it. `index.js` is a separate alternative
entrypoint, not imported by `lumarush.js`. These files each define `InitModule`,
`MODULE_CONFIG`, account RPCs and exchange helpers; do not concatenate them or
load them into one JavaScript scope. Tests evaluate each module in a separate VM
and exercise both registrations and exchange paths. Actual deployed runtime
configuration has not been inspected; no Nakama container was started by these tests.

Server configuration prerequisites (not applied): Render/Cloud Run must inject
`TPX_NAKAMA_EXCHANGE_KEY` as a protected environment/secret value. `render/start.sh`
now forwards it into Nakama `runtime.env`, rejects YAML-unsafe characters without
printing the value, and writes generated runtime config with owner-only access.
Cloud Run operators must add an approved secret-backed environment reference to
the service configuration; no secret name/value or binding is created here.
For local Docker Compose, use a private server runtime-config override containing
this runtime env value; the supplied Compose path mounts `local.yml` directly and
does not forward arbitrary host/container env into Nakama runtime automatically.
Do not pass credentials through the existing traced (`-ecx`) Compose command.

Release coordination:

1. Audit/fix the canonical ArcadeCore template and other generated game callers;
   this local companion covers LumaRush only. Do not grant exchange authority to
   a backend that still forwards payload-selected identities.
2. Review/test both platform and caller commits, then merge to their respective
   `main` branches before any staging release. The platform main workflow may
   automatically deploy staging when its environment gate is enabled.
3. Separately approve provisioning/configuration of per-game/environment
   credentials and coordinate releases from reviewed main revisions. Hardened
   callers without credentials and a hardened gateway without matching mappings
   deliberately fail closed; schedule this availability transition explicitly.
4. Validate controlled staging account flows and negative identity/game cases,
   including magic-link initiation and merge flows that depend on exchange;
   promote reviewed main revisions to production only after validation.

Run the backend tests with Node 20:
`node --test backend/nakama/tests/*.test.js`.
