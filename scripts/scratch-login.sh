#!/usr/bin/env bash
# Logs the agent's browser in to a scratch org: copies a one-time login URL to the clipboard.
#
#   bash scripts/scratch-login.sh so-GH-12
#
# Paste the URL into the Playwright window's address bar. The URL carries a live session, so it
# goes to the clipboard, never to the screen. Run by you, in a terminal that is not shared — the
# agent never runs this (the guard blocks it). Scratch orgs only: never a login to fde-prod.
set -euo pipefail

ALIAS="${1:?usage: scratch-login.sh <scratch org alias>}"
command -v pbcopy >/dev/null || { echo "needs pbcopy (macOS)" >&2; exit 2; }

sf org list --json 2>/dev/null | jq -e --arg a "$ALIAS" '.result.scratchOrgs[] | select(.alias == $a and .isExpired != true)' >/dev/null \
  || { echo "$ALIAS is not an active scratch org" >&2; exit 1; }

sf org open --target-org "$ALIAS" --url-only --json 2>/dev/null | jq -j '.result.url' | pbcopy
echo "Login URL for $ALIAS copied to the clipboard. Paste it into the Playwright window."
