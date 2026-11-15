#!/usr/bin/env bash
# Prints an org's instance URL and nothing else — no token.
#
#   bash scripts/org-url.sh so-GH-12
#
# For the agent's browser check: navigate to "$(bash scripts/org-url.sh so-GH-<n>)/lightning/…".
# `sf org list --json` and `sf org display` would print access tokens; the guard blocks both.
set -euo pipefail

ALIAS="${1:?usage: org-url.sh <alias>}"
url=$(sf org list --json 2>/dev/null | jq -r --arg a "$ALIAS" \
  '[.result[][]? | select(type == "object" and .alias == $a) | .instanceUrl][0] // empty')
[ -n "$url" ] || { echo "no org with alias $ALIAS" >&2; exit 1; }
echo "$url"
