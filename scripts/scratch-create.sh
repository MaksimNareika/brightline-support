#!/usr/bin/env bash
# Creates a task's scratch org so-<name> from the Dev Hub fde-prod and makes it ready to build in.
#
#   bash scripts/scratch-create.sh GH-12          # so-GH-12, 7 days
#   bash scripts/scratch-create.sh smoke 1        # so-smoke, 1 day (setup smoke test)
#
# Run from the task's worktree: it deploys that checkout's force-app, which at Stage 0 is exactly
# origin/test. Order: create → Business Hours (before anything that runs tests) → deploy →
# Support_Agent. Prints alias, username, instance URL and expiry; no secrets.
# Run by the dev workflow's Stage 0, or by you. Idempotent: if so-<name> already exists, nothing is
# created, but every setup step runs again — so a rerun after an interruption finishes the org.
set -euo pipefail

NAME="${1:?usage: scratch-create.sh <name> [days]}"
DAYS="${2:-7}"
DEV_HUB=fde-prod
[[ "$NAME" =~ ^[A-Za-z0-9-]+$ ]] || { echo "name: letters, digits and dashes only" >&2; exit 2; }
ALIAS="so-$NAME"

cd "$(git rev-parse --show-toplevel)"

summary() {
  sf org list --json 2>/dev/null | jq -r --arg a "$ALIAS" '.result.scratchOrgs[] | select(.alias == $a) |
    "alias:        \(.alias)\nusername:     \(.username)\ninstance URL: \(.instanceUrl)\nexpires:      \(.expirationDate)"'
}

# Time zone first, so a missing source fails before a scratch-org slot is spent. fde-test has the
# same Business Hours as fde-prod; fde-prod is read only if fde-test is gone (it expires).
tz=""
for src in fde-test "$DEV_HUB"; do
  tz=$(sf data query --target-org "$src" --json \
         --query "SELECT TimeZoneSidKey FROM BusinessHours WHERE IsDefault = true" 2>/dev/null |
       jq -r '.result.records[0].TimeZoneSidKey // empty') && [ -n "$tz" ] && break
done
[ -n "$tz" ] || { echo "cannot read the Business Hours time zone from fde-test or $DEV_HUB" >&2; exit 1; }

if sf org list --json 2>/dev/null | jq -e --arg a "$ALIAS" '.result.scratchOrgs[] | select(.alias == $a and .isExpired != true)' >/dev/null; then
  echo "$ALIAS already exists; nothing created. Running the setup steps again."
else
  echo "Creating ${ALIAS} for ${DAYS} days from ${DEV_HUB}..."
  sf org create scratch --target-dev-hub "$DEV_HUB" --alias "$ALIAS" \
    --definition-file config/project-scratch-def.json --duration-days "$DAYS" --wait 30 >/dev/null
fi

# Every step below is safe to repeat.
bash scripts/set-business-hours.sh "$ALIAS" "$tz" >/dev/null
echo "Business Hours set: Mon-Fri 09:00-18:00 ($tz)."

echo "Deploying this checkout ($(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD))..."
sf project deploy start --source-dir force-app --target-org "$ALIAS" --wait 30 >/dev/null

username=$(sf org list --json 2>/dev/null | jq -r --arg a "$ALIAS" '.result.scratchOrgs[] | select(.alias == $a) | .username')
assigned=$(sf data query --target-org "$ALIAS" --json --query \
  "SELECT COUNT() FROM PermissionSetAssignment WHERE PermissionSet.Name = 'Support_Agent' AND Assignee.Username = '$username'" |
  jq -r '.result.totalSize')
[ "$assigned" -gt 0 ] || sf org assign permset --name Support_Agent --target-org "$ALIAS" >/dev/null

echo "$ALIAS is ready."
summary
