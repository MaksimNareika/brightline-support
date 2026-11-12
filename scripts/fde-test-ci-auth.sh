#!/usr/bin/env bash
# Gives CI its login to fde-test: stores fde-test's auth URL as the secret SF_AUTH_URL in the
# GitHub `test` environment. The URL goes straight from the CLI into GitHub; it is never printed.
#
#   bash scripts/fde-test-ci-auth.sh
#
# Why not JWT: the External Client App exists only in fde-prod; a scratch org does not have it
# ("External client app is not installed in this org"). The auth URL carries a refresh token for
# fde-test's admin user. It is only good for this scratch org and dies with it. Run again after
# every recreation of fde-test. Run by you, off screen.
#
# Never test this login with `sf org login jwt --username <fde-test user>`: a failed JWT login
# removes the CLI's saved login for that username.
set -euo pipefail

ALIAS=fde-test
cd "$(git rev-parse --show-toplevel)"

info=$(sf org display --target-org "$ALIAS" --verbose --json)
[ -n "$(jq -r '.result.expirationDate // empty' <<<"$info")" ] || {
  echo "$ALIAS is not a scratch org; refusing to hand its login to CI" >&2; exit 1; }

jq -j '.result.sfdxAuthUrl' <<<"$info" | gh secret set SF_AUTH_URL --env test
echo "SF_AUTH_URL set in the GitHub test environment for $(jq -r '.result.username' <<<"$info")."
