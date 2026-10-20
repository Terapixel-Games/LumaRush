# Cloud Run Deployment (LumaRush Nakama)

This folder contains a starter Cloud Run service spec for deploying the Nakama container with the shared Terapixel Postgres strategy.

## Files

- `backend/nakama/cloudrun/service.template.yaml`: Knative service template with placeholder values.

## 1) Build and push the container image

From the repo root:

```bash
PROJECT_ID="<gcp-project>"
IMAGE_URI="us-central1-docker.pkg.dev/${PROJECT_ID}/nakama/lumarush-nakama:$(git rev-parse --short HEAD)"

gcloud builds submit backend/nakama \
  --project "${PROJECT_ID}" \
  --tag "${IMAGE_URI}" \
  --file backend/nakama/Dockerfile.render
```

## 2) Create required secrets

Required secret names in the template:

- `nakama-db-address`
- `nakama-server-key`
- `nakama-session-encryption-key`
- `nakama-session-refresh-encryption-key`
- `nakama-runtime-http-key`
- `nakama-console-password`
- `tpx-platform-internal-key`
- `tpx-magic-link-notify-secret`

Set `nakama-db-address` to a connection string targeting the shared Nakama Postgres instance/database for LumaRush.

## 3) Render and apply the service spec

```bash
SERVICE_ACCOUNT_EMAIL="<cloud-run-runtime-service-account>"
CLOUDRUN_SERVICE="lumarush-nakama"
CLOUDSQL_INSTANCE_CONNECTION_NAME="<project>:<region>:<instance>"
TPX_PLATFORM_IDENTITY_NAKAMA_AUTH_URL="https://terapixel.games/api/v1/auth/nakama"
TPX_PLATFORM_USERNAME_VALIDATE_URL="https://terapixel.games/api/v1/identity/internal/username/validate"
TPX_PLATFORM_TELEMETRY_EVENTS_URL="https://terapixel.games/api/v1/telemetry/events"

sed \
  -e "s|__CLOUDRUN_SERVICE__|${CLOUDRUN_SERVICE}|g" \
  -e "s|__SERVICE_ACCOUNT_EMAIL__|${SERVICE_ACCOUNT_EMAIL}|g" \
  -e "s|__IMAGE_URI__|${IMAGE_URI}|g" \
  -e "s|__CLOUDSQL_INSTANCES__|${CLOUDSQL_INSTANCE_CONNECTION_NAME}|g" \
  -e "s|__TPX_PLATFORM_IDENTITY_NAKAMA_AUTH_URL__|${TPX_PLATFORM_IDENTITY_NAKAMA_AUTH_URL}|g" \
  -e "s|__TPX_PLATFORM_USERNAME_VALIDATE_URL__|${TPX_PLATFORM_USERNAME_VALIDATE_URL}|g" \
  -e "s|__TPX_PLATFORM_TELEMETRY_EVENTS_URL__|${TPX_PLATFORM_TELEMETRY_EVENTS_URL}|g" \
  backend/nakama/cloudrun/service.template.yaml > /tmp/lumarush-nakama-service.yaml

gcloud run services replace /tmp/lumarush-nakama-service.yaml \
  --project "${PROJECT_ID}" \
  --region "us-central1"
```

`backend/nakama/render/start.sh` is reused for Cloud Run. It accepts DB config via `DB_ADDRESS` (preferred), `DATABASE_URL`, or `DB_*` parts.


## Identity exchange rollout gate (local preparation only)

The service template now injects server-only `TPX_NAKAMA_EXCHANGE_KEY` via Secret
Manager. Environment-scoped GitHub **variables** `TPX_NAKAMA_EXCHANGE_SECRET` and
`TPX_NAKAMA_EXCHANGE_SECRET_VERSION` hold only a secret resource name and a positive
numeric version. No credential value belongs in Actions variables, logs, rendered
YAML `value` fields or client builds. Manual template rendering must substitute
both new placeholders as well. The workflow rejects missing/malformed metadata
before cloud authentication; it does not create secrets or grant access.

Proposed resource names, subject to inventory and separate approval:
`lumarush-nakama-exchange-staging` and `lumarush-nakama-exchange-prod`, each in the
actual target project and distinct from every other game/environment. Bind the
runtime service account to secret accessor on its single environment's resource;
use an approved immutable version. Gateway runtime receives the matching lumarush
mapping through its own aggregate secret. Do not reuse the platform admin key.
Render fallback needs a protected, separately approved `TPX_NAKAMA_EXCHANGE_KEY`
setting; the blueprint declares it `sync: false` and supplies no value.

The workflow defaults `CLOUDRUN_SERVICE` to `lumarush-nakama` for both targets.
Before any release, verify explicit staging/production project/service/runtime
account/DB/URL isolation: the default is not evidence of separate environments.
Merging main triggers staging and Pages workflows; tags/manual targets can deploy
production without proving main ancestry. Do not merge/tag/dispatch merely to
validate this wiring. Current remote PR13 is unchanged by this local follow-up.
