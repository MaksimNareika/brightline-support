#!/usr/bin/env bash
# Gates for agent defects that a compile and a test run do not catch.
#   1. hardcoded record IDs in added lines
#   2. weakened tests: fewer assertions in a test class than on the base branch
#   3. permission changes (profiles, permission sets) without the `permissions-reviewed` PR label
# Exit 1 on any failure. Usage: risk-scan.sh <base-ref> [labels, comma-separated]
set -uo pipefail

base="${1:?usage: risk-scan.sh <base-ref> [labels]}" labels="${2:-}"
fails=0
fail() { echo "::error::$1"; fails=$((fails+1)); }

# 1. Salesforce IDs: 15 or 18 chars starting with a known key prefix, in quotes.
ids=$(git diff -U0 "$base"...HEAD -- 'force-app/**/*.cls' 'force-app/**/*.trigger' 'force-app/**/*.js' \
  | grep -E '^\+' | grep -vE '^\+\+\+' \
  | grep -oE "['\"](001|003|005|00D|00G|00e|500|01p|0PS|a0[0-9A-Za-z])[0-9A-Za-z]{12}([0-9A-Za-z]{3})?['\"]" | sort -u)
[ -z "$ids" ] || fail "hardcoded record IDs added: $(echo $ids | tr '\n' ' ') — move them to custom metadata"

# 2. Assertion count per modified test class must not drop.
count() { grep -cE '\b(Assert\.[a-zA-Z]+|System\.assert[a-zA-Z]*)\s*\(' 2>/dev/null || true; }
for f in $(git diff --name-only --diff-filter=M "$base"...HEAD -- 'force-app/**/*Test.cls'); do
  before=$(git show "$base:$f" | count); after=$(count < "$f")
  [ "${after:-0}" -ge "${before:-0}" ] || fail "$f: assertions dropped from $before to $after — a test was weakened"
done

# 3. Permission changes need an explicit human look.
perm=$(git diff --name-only "$base"...HEAD -- 'force-app/**/profiles/*' 'force-app/**/permissionsets/*' 'force-app/**/permissionsetgroups/*')
if [ -n "$perm" ]; then
  if printf '%s' "$labels" | tr ',' '\n' | grep -qx 'permissions-reviewed'; then
    echo "permission changes acknowledged by label: $perm"
  else
    fail "permission metadata changed ($(echo $perm | tr '\n' ' ')) — a human reviews the diff and adds the 'permissions-reviewed' label"
  fi
fi

[ $fails -eq 0 ] && echo "risk scan: clean" || exit 1
