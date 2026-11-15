# Demo environment setup

One-time setup, about three hours including the smoke test. Steps marked **(you)** need a browser
or an account decision; the rest are commands. Each step ends with a **Check**: do not move on
until it passes. Items marked **[§8]** depend on changes that are planned but not built yet.

The environment:

| Org / place | Role | Who changes it |
|---|---|---|
| `so-GH-<n>` | Scratch org, one per task, 1–7 days | the agent, while building that task |
| `fde-test` | Scratch org, QA/UAT, long-lived (up to 30 days, then recreated) | CI only, on merge to `test` |
| `fde-prod` | the one Developer Edition org: production **and Dev Hub** | CI only, on merge to `main`, after a required reviewer |

Only one real org: Salesforce allows one Developer Edition sign-up per email address, and the
sign-up form wants a work email. On a real project QA is a sandbox; a Developer Edition org has no
sandboxes, so a long-lived scratch org plays that role. The trade-off: it expires, and it takes one
of the Dev Hub's few active scratch-org slots (Developer Edition: 3 active, 6 per day).
| `feature/GH-<n>-*` | branch + git worktree per task | the agent |
| `test`, `main` | protected branches | a human merges a PR |

## 0. A clean machine profile (recommended)

Record and present from a separate macOS user (System Settings → Users & Groups → Add User,
e.g. `fde-demo`). Your daily profile has client orgs in `sf org list`, client plugins in Claude
Code, another GitHub account in `gh` and notifications — any of which can appear in a recording.
In the new profile install: Salesforce CLI, Node 22 LTS, Python 3, Git, GitHub CLI, `jq`, Java 17+
(for the Apex language server), Claude Code, VS Code.

**Check:** `sf --version && node -v && java -version && gh --version && jq --version && claude --version`
prints a version for each.

## 1. One Developer Edition org — production and Dev Hub (you)

Sign up once at <https://developer.salesforce.com/signup>, with a username such as
`<you>.fde-prod@<domain>` (usernames are unique across all of Salesforce). A second sign-up with the
same email is refused ("you already have an active Developer Edition…"); you do not need one.

In this org (`fde-prod`):

- Setup → Business Hours → edit the default: Mon–Fri 09:00–18:00, your time zone. A new org's
  default is 24/7, which makes every business-hours calculation equal clock time. Scratch orgs get
  the same hours, and this time zone, from a script.
- Setup → Users → create `CI Integration` (the second Salesforce licence), profile System
  Administrator. In a real project this user gets a deploy-only permission set; in a Developer
  Edition org System Administrator is the practical option — say so in the lecture.
- Setup → Dev Hub → **Enable Dev Hub**. This cannot be turned off again. On real projects the Dev
  Hub is usually the customer's production org; here the Developer Edition org plays that role.

**Check:** Setup → Dev Hub shows "Enabled".

## 2. Authorise locally

```bash
sf org login web --alias fde-prod --set-default-dev-hub
sf org list limits --target-org fde-prod | grep -i scratch
```

Do **not** set `fde-prod` as the default `target-org`. `fde-test` is created in step 8, once CI and
`test` exist.

**Check:** `sf org list` shows `fde-prod` `Connected`, marked as the Dev Hub, and nothing else. Write
the `ActiveScratchOrgs` and `DailyScratchOrgs` maximums from the last command into the prep file —
every dry run, rehearsal and live run uses them. `fde-test` holds one active slot permanently.

## 3. Claude access

Use the Claude access approved for this lecture. If it goes through an AI gateway, the gateway is
configured by environment variables (`ANTHROPIC_BASE_URL` plus a token variable) in the shell
profile of the demo user. **Never run `/status`, `env` or `claude auth status` on screen** — they
show the gateway host.

**Check (off screen):** `claude -p "say ok"` prints `ok`.

## 4. Browser for the in-org check

```bash
npx -y @playwright/mcp@0.0.83 --help >/dev/null && echo ok
```

The browser profile persists between sessions. Each new scratch org needs one human login: Stage 0
of `dev-workflow` creates the org, then **you** run

```bash
bash scripts/scratch-login.sh so-GH-<n>      # copies a one-time login URL to the clipboard (macOS: pbcopy)
```

in a terminal that is **not** shared, and paste the URL into the Playwright window's address bar.
The URL carries a live session, so it goes to the clipboard, never to the screen. The agent never
sees it: the guard hook blocks `sf org open` and `scratch-login.sh`. The agent finds the org's
address with `scripts/org-url.sh`, which prints the instance URL only.

**Check:** done in the smoke test (step 10, S4).

## 5. Apex language server [§8]

The `sf-sdlc` plugin ships an LSP configuration for Salesforce's Apex language server (needs Java
from step 0). It lets the agent see compile errors before it deploys.

**Check:** smoke test S5.

## 6. JWT for CI

Certificate and key, once, outside the repo:

```bash
mkdir -p ~/fde-ci && cd ~/fde-ci
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
  -keyout server.key -out server.crt -subj "/CN=fde-ci"
```

In `fde-prod` (you): Setup → External Client App Manager → New. The app serves `fde-prod` only: an
External Client App exists only in the org it was created in, so a scratch org refuses it
("External client app is not installed in this org"). CI reaches `fde-test` with an auth URL
instead (step 8).

- OAuth enabled; callback `http://localhost:1717/OAuthRedirect`
- Scopes: `api`, `refresh_token, offline_access`, `web`
- Flow enablement: **JWT Bearer Flow**, upload `server.crt`
- Policies: Permitted users = *Admin approved users are pre-authorized*; add the System
  Administrator profile (or a permission set assigned to `CI Integration`)
- Copy the **Consumer Key**

**Check:**

```bash
sf org login jwt --client-id <consumer key> --username <ci integration username> \
  --jwt-key-file ~/fde-ci/server.key --instance-url https://login.salesforce.com --alias ci-check
sf org logout --target-org ci-check --no-prompt
```

The login succeeds.

## 7. GitHub (you)

Repos in the EPAM GitHub org: `brightline-support` (this project) and `sf-sdlc-plugins`.
If `gh` is logged in to another account: `gh auth login` adds a second one, `gh auth switch` picks
it. Check `gh auth status` before every push — off screen.

In `brightline-support` → Settings:

| Where | What |
|---|---|
| Environments → `prod` | vars `SF_CLIENT_ID` (the consumer key), `SF_USERNAME` (`CI Integration`), `SF_INSTANCE_URL` (`https://login.salesforce.com`); secret `SF_JWT_KEY` (contents of `server.key`); **Required reviewers: you** — the last human gate before production |
| Environments → `test` | nothing yet: in step 8, `fde-test-create.sh` sets the secret `SF_AUTH_URL` (`fde-test`'s auth URL) itself. No JWT key here — the key that can log in to production stays in `prod` |
| Secrets → Actions | the Claude credential for the AI jobs, the same variables as the local shell: with a gateway `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN` and, if used, `ANTHROPIC_CUSTOM_HEADERS` — all **secrets**, so the host never appears in YAML or logs; without one `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` |
| Actions → General | Actions enabled; `anthropics/claude-code-action` allowed if the org restricts third-party actions |
| Branches → `test`, `main` | require a PR; require status checks `static`, `org-drift` [§8] and `validate`; require branches to be up to date; no direct pushes, no force-push. The checks appear in the list only after the first PR has run them |
| Labels | `feature`, `bug`, `permissions-reviewed` |

**Check:** Settings → Environments lists `test` and `prod`; `prod` shows you as required reviewer.

## 8. Seed `fde-prod`, create `fde-test`

```bash
git switch main && sf project deploy start --source-dir force-app --target-org fde-prod --test-level RunLocalTests
bash scripts/fde-test-create.sh        # scratch org from fde-prod, deploys origin/test, sets Business Hours
```

The script ends by running `scripts/fde-test-ci-auth.sh`, which stores `fde-test`'s auth URL as the
secret `SF_AUTH_URL` in the GitHub `test` environment, straight from the CLI, never printed. CI's
login step uses it when it is set and JWT otherwise. The auth URL is a refresh token for
`fde-test`'s admin: it works only for that scratch org and dies with it. JWT cannot be used here:
the External Client App exists only in `fde-prod` (step 6).

Do **not** test this with `sf org login jwt --username <fde-test user>`: the login fails, and a
failed JWT login removes the CLI's saved login for that username, so `fde-test` disappears from
`sf org list`. The check is the first CI run against `fde-test`: rerun `validate` on an open PR to
`test`, or merge one.

Issue #3 *Business hours helper* (closed) is the ticket `CLAUDE.md` names as the owner of
`BusinessHoursCalculator`. On a fresh repo, create such an issue and put its number in `CLAUDE.md`.
These deploys are done by you, by hand, once. From here on only CI deploys to `fde-test` and
`fde-prod`.

**Check:** both commands succeed, the script shows Monday 09:00–18:00 and Saturday empty and ends
with `SF_AUTH_URL set`, a CI run against `fde-test` logs in, and
`sf apex run test --target-org fde-test --test-level RunLocalTests --wait 10` passes. `main` (and `fde-prod`) does not have the helper (#3) yet; it reaches production with the first release.
Write `fde-test`'s expiry date into the prep file.

### Recreating `fde-test`

A scratch org cannot be extended. Recreate `fde-test` when its expiry date is before the next demo
phase you need it for — at the latest before phase A, so it lasts through the lecture (runbook).
It costs one daily scratch-org slot and about the time of one full deploy.

```bash
sf org delete scratch --target-org fde-test --no-prompt     # you; skip if it has already expired
bash scripts/fde-test-create.sh                             # or: … 20, for fewer days
```

The script refreshes `SF_AUTH_URL` itself. If `fde-test` vanished from `sf org list` while it
still exists in the Dev Hub (Setup → Active Scratch Orgs), delete it there instead of with the
command above. The new org holds exactly what
`test` holds, with no drift. Validations CI ran against the old org are void; the next merge falls
back to a full deploy by itself.

## 9. Plugin

The project does **not** auto-enable the plugin; installing it is a step in the live demo.

```text
/plugin marketplace add <epam-org>/sf-sdlc-plugins
/plugin install sf-sdlc@fde-sdlc
/reload-plugins
```

**Check:** `/plugins` lists `sf-sdlc`; `/agents` lists the `sdlc-*` agents. Keep it installed for
the smoke test and the dry run; uninstall it before the lecture (runbook, phase F).

For a team, the same install goes into `.claude/settings.json` as `extraKnownMarketplaces` +
`enabledPlugins` — show that on a slide, not live.

## 10. Smoke test — the whole environment, once

Run this after steps 0–9 and again after any change to the plugin or the CI workflows. Record the
times; S3 decides whether the scratch org can be created live.

| # | Check | How | Pass when |
|---|---|---|---|
| S1 | Orgs | `sf org list` | only `fde-prod` (Dev Hub) and `fde-test` (scratch, expiry after the lecture day), both `Connected` |
| S2 | Scratch quota | `sf org list limits --target-org fde-prod \| grep -i scratch` | at least 2 active and 2 daily remaining, with `fde-test` already counted |
| S3 | Scratch org end to end | on an up-to-date `test` checkout: `time bash scripts/scratch-create.sh smoke 1` (creates `so-smoke` for 1 day: Business Hours, deploy of the checkout, `Support_Agent`) | finishes; note the minutes. Then `sf data query --target-org so-smoke -q "SELECT MondayStartTime, MondayEndTime FROM BusinessHours WHERE IsDefault = true"` shows 09:00/18:00, and `sf apex run test --target-org so-smoke --test-level RunLocalTests --wait 10` passes |
| S4 | Browser | `bash scripts/scratch-login.sh so-smoke` off screen, paste the URL into the Playwright window; ask Claude: *"open a Gold case in so-smoke and take a screenshot"* | the record page renders in the Playwright window, the screenshot is saved |
| S5 | Apex LSP **[§8]** | add `Integer x = 'a';` to a class in the worktree; ask Claude *"check this class for compile errors without deploying"*; revert | the error is reported from the language server, with no deploy |
| S6 | Guard | ask Claude to deploy `force-app` to `fde-prod`, then to `fde-test`, then to `so-smoke` | the first two are blocked by `sf-sdlc guard`, the third runs |
| S7 | CI, PR to `test` | branch from `test`, change one line in `README.md`, open a PR to `test` | `static`, `org-drift`, `validate` green; one AI review comment within ~5 minutes |
| S8 | CI, merge to `test` | merge S7 | the `Deploy` job ran **Quick deploy the validated job** and skipped the full deploy |
| S9 | Deploy-failure triage **[§8]** | branch from `test`, add a class that calls `NoSuchClass.run()`, open a PR | `validate` fails; a triage comment names `NoSuchClass` and the file. Close the PR without merging |
| S10 | CI to prod + release notes **[§8]** | branch from **`main`** (not `test` — that would ship the helper, #3), change `README.md`, PR to `main`, merge | `validate` against `fde-prod` green; the `Deploy` job waits for your approval; after approval it quick-deploys; release notes are produced |
| S11 | Clean up | **you**: `sf org delete scratch --target-org so-smoke --no-prompt`; `git worktree prune` | S2's active count is back to where it started |

If S7's AI comment never appears, check the job log for a connection error: GitHub-hosted runners
may not reach the gateway. Fallback: run the review headless from the demo machine
(`claude -p` with the same prompt as `ai-review.yml`) and say so in the lecture.
