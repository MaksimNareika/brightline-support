#!/usr/bin/env bash
# Creates fde-test: the long-lived QA scratch org, from the Dev Hub fde-prod.
#
#   bash scripts/fde-test-create.sh            # 30 days
#   bash scripts/fde-test-create.sh 20         # fewer days, e.g. to end soon after the lecture
#
# Sets the default Business Hours to Mon–Fri 09:00–18:00 in fde-prod's Business Hours time zone,
# deploys origin/test, assigns Support_Agent, and gives CI its login (fde-test-ci-auth.sh).
# Run by you, off screen — not by the agent and not by CI.
#
# A scratch org lives at most 30 days and cannot be extended. It holds one of the Dev Hub's
# ActiveScratchOrgs slots for its whole life.
set -euo pipefail

DEV_HUB=fde-prod
ALIAS=fde-test
DAYS="${1:-30}"

cd "$(git rev-parse --show-toplevel)"

if existing=$(sf org display --target-org "$ALIAS" --json 2>/dev/null); then
  if [ "$(jq -r '.result.expirationDate // empty' <<<"$existing")" = "" ]; then
    # Not a scratch org: the alias points at a real org, possibly production. Never touch it.
    echo "$ALIAS points to a non-scratch org ($(jq -r '.result.username' <<<"$existing"))." >&2
    echo "Remove the alias (the org is not changed): sf alias unset $ALIAS" >&2
  else
    echo "$ALIAS already exists and is reachable. To replace it, delete it first (you):" >&2
    echo "  sf org delete scratch --target-org $ALIAS --no-prompt" >&2
  fi
  exit 1
fi

# The Business Hours time zone comes from fde-prod, so both orgs calculate the same. Read it
# before creating the org, so a missing setup step fails without spending a scratch-org slot.
tz=$(sf data query --target-org "$DEV_HUB" --json \
       --query "SELECT TimeZoneSidKey FROM BusinessHours WHERE IsDefault = true" |
     jq -r '.result.records[0].TimeZoneSidKey')
[ -n "$tz" ] && [ "$tz" != null ] || { echo "cannot read Business Hours from $DEV_HUB" >&2; exit 1; }

echo "Creating ${ALIAS} for ${DAYS} days from ${DEV_HUB}..."
sf org create scratch --target-dev-hub "$DEV_HUB" --alias "$ALIAS" \
  --definition-file config/project-scratch-def.json --duration-days "$DAYS" \
  --no-track-source --wait 30 >/dev/null

# Business Hours first: the deploy runs the tests, and business-hours tests must see real hours.
bash scripts/set-business-hours.sh "$ALIAS" "$tz"

# Deploy exactly what the test branch holds, whatever is checked out here.
git fetch --quiet origin test
src=$(mktemp -d)
trap 'git worktree remove --force "$src" >/dev/null 2>&1 || true' EXIT
git worktree add --quiet --detach "$src" origin/test
echo "Deploying origin/test ($(git rev-parse --short origin/test))…"
(cd "$src" && sf project deploy start --source-dir force-app --target-org "$ALIAS" \
  --test-level RunLocalTests --wait 30)

sf org assign permset --name Support_Agent --target-org "$ALIAS" >/dev/null

bash scripts/fde-test-ci-auth.sh

expires=$(sf org display --target-org "$ALIAS" --json | jq -r '.result.expirationDate')
echo
echo "$ALIAS is ready. Expires: $expires — the lecture day must be before that."
