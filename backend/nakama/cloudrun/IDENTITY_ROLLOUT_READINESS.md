# Identity rollout readiness — 2026-10-20

Status: NOT ready to merge or deploy. Preparation only, no credentials, live settings,
publication or deployment changed. Verified GitHub connector identity: TeraPixelGames.

## Reviewed revisions and checks

- Platform draft PR7: `7d8e2af8a2ae2d5a38dbe24b16c651b4873ac5bf`, base main
  `bfa62903fd6044727528038148a2b774ebd2ef55`. Test check success; GitHub mergeable
  state blocked (cause not established; do not bypass). Local Node20 full suite 94/94.
- LumaRush draft PR13: `bca6930c5fec5f3edb901ea6d1bfeb49a185de4c`, base main
  `71bb381dab1fe1fc9b78ce34d65b140d528438ca`. All five reported checks success
  (unit, UAT, backend-tests, godot-tests, sync). Local backend suite 17/17.
- This local follow-up is based on PR13, not included in either remote PR. Backend
  tests including secret-reference/preflight coverage: 19/19. No engine/container
  startup or live Nakama test was performed. Shell syntax and diff checks pass.

## Remaining security and compatibility gates

Gateway authentication binds a dedicated backend credential to normalized game ID,
signs game_id, and keeps issuer/audience server-owned. It authenticates a backend
assertion, not a Nakama player JWT. A credential authorizes assertions for any user
within its game; never grant one to payload-selected-user RPCs.

Platform save, IAP, flags and telemetry routes do not enforce signed game_id against
request game_id. A local-only characterization using fixed signed test fixtures and
mock services confirmed HTTP200 for a lumarush token requesting different-game in
save sync and IAP verify. No real balances, provider or production was touched.
Correct downstream checks before claiming game isolation. Preserve intentional
platform-wide web/magic-link sessions through an explicit policy, rather than
blindly requiring game_id everywhere. IAP entitlements also returns account-wide
coins; decide/filter its game view consistently. New scoped tokens must reject
mismatched games before store/provider work. Add tests for matching/mismatched and
malformed claims, legacy Nakama claims, web sessions and wrong audience.

Public magic links must remain available: do not make the entire gateway private.
Existing issued sessions remain valid until expiry; deleting the exchange mapping
stops new exchanges only. Incident-driven session revocation requires separate
approval and a defined blast radius. No allow-all or admin-key fallback is acceptable.

Active LumaRush runtime is lumarush.js in local.yml and render/start.sh; index.js is
an alternative, independently tested, not a replacement for active-path inspection.
Active config uses TPX_GAME_ID and the full identity exchange URL. Alternative
index.js uses GAME_ID and PLATFORM_IDENTITY_URL. Container environment alone is
insufficient for Compose: mounted local.yml needs a private runtime.env override.
Do not use the traced Compose startup command for secret values.

A fresh default-branch GitHub search still returned 68 route matches with
incomplete_results=false. The 21 copied game index.js files retain old blob
4b5209bf5b04e2a25d399fc6ae9f9eba621570d0; racer and GlowPath remain distinct variants.
ArcadeCore canonical template retains the old blob. Previous local canonical fix
29d0f7d and platform scaffold c42eee7 remain unpublished. Inventory is source-only,
not proof that every matching module is deployed. Additional active SnakeGame and
color_crunch paths need proof headers; GlowPath sends admin-key instead. Do not
provision keys for those callers until their actual entrypoints are corrected.

## Deployment gates

Platform main pushes can auto-deploy staging when CLOUDRUN_ENABLED is enabled;
CI and deployment are separate workflows. Platform deployment actions retain
floating version refs even though CI was pinned; the previously observed full-SHA
organization policy can reject deploy workflow startup. Live policy/gates unverified.
The platform workflow deploys all manifest services, not identity only, and applies
public/private flags. Do not dispatch it as an identity-only operation without
separately authorizing that scope or first preparing a narrow release mechanism.

LumaRush main pushes target staging and can publish Pages. Version tags/manual
paths can target production. Neither repository proves main ancestry for manual/tag
releases. LumaRush defaults both environments' service name to lumarush-nakama;
explicit project/service/runtime-account/DB/URL isolation must be confirmed before
merge. External Render dashboard hooks and live GitHub environment gates were not
inspected. A successful CI check does not certify deployment readiness.

## Proposed credential destinations (names require approval/inventory)

For EACH environment independently:

1. LumaRush project Secret Manager resource `lumarush-nakama-exchange-staging` or
   `lumarush-nakama-exchange-prod`, immutable numeric version. Runtime env destination
   TPX_NAKAMA_EXCHANGE_KEY via secretKeyRef; startup forwards into Nakama runtime.env.
   GitHub staging/production variables TPX_NAKAMA_EXCHANGE_SECRET and
   TPX_NAKAMA_EXCHANGE_SECRET_VERSION contain metadata only.
2. Platform project aggregate resource `terapixel-nakama-exchange-keys-staging` or
   `terapixel-nakama-exchange-keys-prod`, immutable version. Runtime env destination
   NAKAMA_EXCHANGE_KEYS_JSON, with the matching lumarush entry. Use only the
   identity-gateway entry in environment CLOUDRUN_SECRET_REFS_BY_SERVICE, never
   common configuration that exposes the aggregate to unrelated services.
3. Existing gateway runtime account: secretAccessor only on its aggregate resource.
   Existing LumaRush runtime account: secretAccessor only on its game's resource.
   No game runtime should read the aggregate or other games/environments' secrets.
4. A separately approved provisioning principal needs secret create if absent,
   versions.add on named resources, and getIamPolicy/setIamPolicy only where access
   bindings must change. Runtime readers do not need secret administration.
5. Existing deploy principal needs target Cloud Run update and iam.serviceAccounts.actAs
   on the selected runtime account, plus existing build/artifact permissions for a
   release. Do not create service-account keys or grant project-wide secret access.
   Actual resource IDs, project IDs and account emails remain unverified: do not
   substitute guessed targets into commands. GitHub TeraPixel identity does not
   establish GCP authority.

Cloud Run/Secret Manager references:
https://docs.cloud.google.com/run/docs/configuring/services/secrets
https://docs.cloud.google.com/secret-manager/docs/access-control

## Staged release and rollback plan — requires later approvals

1. Finish downstream game binding and caller/runtime inventory; review local wiring,
   canonical/scaffold corrections, release action pins and main-ancestry gates.
2. Inspect target metadata/IAM and environment approvals read-only, recording exact
   project, region, service, runtime account, secret metadata, previous image/revision
   and pinned secret version. Do not read/print existing secret payloads in reports.
3. Obtain bounded staging-only approval for named secret provisioning/bindings and
   exact revision deployment. Confirm main merges cannot unintentionally deploy
   production/shared targets. Merge reviewed code to each main before staging.
4. There is no safe compatibility bypass: schedule the availability transition.
   Deploy the hardened gateway then trusted caller with matching staging secret;
   old callers receive 401. If caller is released first, its protected credential
   may be sent to an old gateway that ignores it, so it does not close the hole.
   Admit only audited games; leave others unconfigured/fail-closed until ready.
5. Validate a real controlled staging Nakama login/exchange end-to-end; use the two
   authenticated test accounts to verify caller identity cannot be overridden.
   Missing/wrong/game-mismatched proof must fail; verify audience and downstream
   cross-game denial, public magic-link success, secret-free logs and restart
   configuration. Record exact main SHAs/images and metrics without token values.
6. After staging acceptance, request separate production credential/binding and
   release approval, using reviewed main ancestry and tested artifacts. Never tag,
   merge, dispatch or change live IAM as part of this preparation.
7. Rollback must retain the authenticated gateway. Revert a faulty caller to a
   previously hardened compatible revision, or disable the affected game's mapping
   and accept exchange unavailability. Do not route traffic to the old vulnerable
   gateway or reinstate proof-free/admin-key fallback. Retain previous hardened
   images and pinned secret versions; coordinate both ends for rotation/rollback.
   Revocation requires a new loaded mapping/revision; existing issued sessions need
   separate expiry/revocation handling. Capture health/401/error rates before/after.

Next approval should first identify/inspect exact staging cloud and GitHub
configuration metadata under an authorized TeraPixel account; it is not yet safe to
request a broad production rollout. Publication, main merges, credentials/IAM and
staging deployment remain separate action-time approvals. PostgreSQL startup stays
pending and wallet/billing/saves/saga/loading work remains paused.
