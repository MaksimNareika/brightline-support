#!/usr/bin/env bash
# Sets an org's default Business Hours to Mon–Fri 09:00–18:00, no hours on Saturday and Sunday.
#
#   bash scripts/set-business-hours.sh <org alias> [time zone]
#
# A new org's default is 24/7, which makes every business-hours calculation equal clock time.
# The time zone defaults to that of fde-test (the same as fde-prod, which fde-test-create.sh copies),
# so all orgs calculate the same. Callers pass it: fde-test-create.sh reads fde-prod;
# scratch-create.sh reads fde-test, and fde-prod only when fde-test has expired (read-only).
set -euo pipefail

ORG="${1:?usage: set-business-hours.sh <org alias> [time zone]}"
TZ_SID="${2:-}"

if [ -z "$TZ_SID" ]; then
  TZ_SID=$(sf data query --target-org fde-test --json \
             --query "SELECT TimeZoneSidKey FROM BusinessHours WHERE IsDefault = true" |
           jq -r '.result.records[0].TimeZoneSidKey')
  [ -n "$TZ_SID" ] && [ "$TZ_SID" != null ] || { echo "cannot read Business Hours from fde-test; pass the time zone" >&2; exit 1; }
fi

# Apex cannot update BusinessHours; the REST API can.
api=$(sf org display --target-org "$ORG" --json | jq -r '.result.apiVersion')
bh=$(sf data query --target-org "$ORG" --json \
       --query "SELECT Id FROM BusinessHours WHERE IsDefault = true" | jq -r '.result.records[0].Id')
body=$(jq -n --arg tz "$TZ_SID" '
  {TimeZoneSidKey: $tz}
  + ([ "Monday","Tuesday","Wednesday","Thursday","Friday" ]
     | map({(.+"StartTime"): "09:00:00.000Z", (.+"EndTime"): "18:00:00.000Z"}) | add)
  + ([ "Saturday","Sunday" ]
     | map({(.+"StartTime"): null, (.+"EndTime"): null}) | add)')
sf api request rest "/services/data/v$api/sobjects/BusinessHours/$bh" --method PATCH \
  --body "$body" --target-org "$ORG" >/dev/null

sf data query --target-org "$ORG" \
  --query "SELECT TimeZoneSidKey, MondayStartTime, MondayEndTime, SaturdayStartTime FROM BusinessHours WHERE IsDefault = true"
