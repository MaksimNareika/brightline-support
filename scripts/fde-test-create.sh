#!/usr/bin/env bash
# Creates fde-test: the long-lived QA scratch org, from the Dev Hub fde-prod.
#
#   bash scripts/fde-test-create.sh            # 30 days
#   bash scripts/fde-test-create.sh 20         # fewer days, e.g. to end soon after the lecture
#
# Deploys origin/test, sets the default Business Hours to Mon–Fri 09:00–18:00 in fde-prod's
# Business Hours time zone, assigns Support_Agent, and prints what the GitHub `test` environment
# needs. Run by you, off screen — not by the agent and not by CI.
#
# A scratch org lives at most 30 days and cannot be extended. It holds one of the Dev Hub's
# ActiveScratchOrgs slots for its whole life.
set -euo pipefail

DEV_HUB=fde-prod
ALIAS=fde-test
DAYS="${1:-30}"

cd "$(git rev-parse --show-toplevel)"

if sf org display --target-org "$ALIAS" >/dev/null 2>&1; then
  echo "$ALIAS already exists and is reachable. To replace it, delete it first (you):" >&2
  echo "  sf org delete scratch --target-org $ALIAS --no-prompt" >&2
  exit 1
fi

# The Business Hours time zone comes from fde-prod, so both orgs calculate the same.
tz=$(sf data query --target-org "$DEV_HUB" --json \
       --query "SELECT TimeZoneSidKey FROM BusinessHours WHERE IsDefault = true" |
     jq -r '.result.records[0].TimeZoneSidKey')
[ -n "$tz" ] && [ "$tz" != null ] || { echo "cannot read Business Hours from $DEV_HUB" >&2; exit 1; }

echo "Creating $ALIAS for $DAYS days from $DEV_HUB…"
sf org create scratch --target-dev-hub "$DEV_HUB" --alias "$ALIAS" \
  --definition-file config/project-scratch-def.json --duration-days "$DAYS" \
  --no-track-source --wait 30 >/dev/null

# Deploy exactly what the test branch holds, whatever is checked out here.
git fetch --quiet origin test
src=$(mktemp -d)
trap 'git worktree remove --force "$src" >/dev/null 2>&1 || true' EXIT
git worktree add --quiet --detach "$src" origin/test
echo "Deploying origin/test ($(git rev-parse --short origin/test))…"
(cd "$src" && sf project deploy start --source-dir force-app --target-org "$ALIAS" \
  --test-level RunLocalTests --wait 30)

# Apex cannot update BusinessHours; the REST API can. Saturday and Sunday: no hours.
api=$(sf org display --target-org "$ALIAS" --json | jq -r '.result.apiVersion')
bh=$(sf data query --target-org "$ALIAS" --json \
       --query "SELECT Id FROM BusinessHours WHERE IsDefault = true" | jq -r '.result.records[0].Id')
body=$(jq -n --arg tz "$tz" '
  {TimeZoneSidKey: $tz}
  + ([ "Monday","Tuesday","Wednesday","Thursday","Friday" ]
     | map({(.+"StartTime"): "09:00:00.000Z", (.+"EndTime"): "18:00:00.000Z"}) | add)
  + ([ "Saturday","Sunday" ]
     | map({(.+"StartTime"): null, (.+"EndTime"): null}) | add)')
sf api request rest "/services/data/v$api/sobjects/BusinessHours/$bh" --method PATCH \
  --body "$body" --target-org "$ALIAS" >/dev/null
sf data query --target-org "$ALIAS" \
  --query "SELECT TimeZoneSidKey, MondayStartTime, MondayEndTime, SaturdayStartTime FROM BusinessHours WHERE IsDefault = true"

sf org assign permset --name Support_Agent --target-org "$ALIAS" >/dev/null

info=$(sf org display --target-org "$ALIAS" --json)
username=$(jq -r '.result.username' <<<"$info")
expires=$(jq -r '.result.expirationDate' <<<"$info")

cat <<EOF

$ALIAS is ready. Expires: $expires — the lecture day must be before that.

GitHub → Settings → Environments → test (SF_CLIENT_ID and SF_JWT_KEY are the same as prod's):
  gh variable set SF_USERNAME     --env test --body "$username"
  gh variable set SF_INSTANCE_URL --env test --body "https://test.salesforce.com"
EOF
