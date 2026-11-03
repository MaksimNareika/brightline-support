# Demo environment setup

One-time setup, about two hours. Steps marked **(you)** need a browser or an account decision; the
rest are commands.

## 0. A clean machine profile (recommended)

Record and present from a separate macOS user (System Settings → Users & Groups → Add User,
e.g. `fde-demo`). Your daily profile has client orgs in `sf org list`, client plugins in Claude
Code, a client GitHub account in `gh`, and client notifications — any of which can appear on a
recording. In the new profile install: Salesforce CLI, Node 22 LTS, Python 3, Git, GitHub CLI,
Claude Code, VS Code.

## 1. Two Developer Edition orgs (you)

Sign up twice at <https://developer.salesforce.com/signup>. Use usernames you will recognise, e.g.
`<you>.fde-prod@<domain>` and `<you>.fde-test@<domain>` (usernames must be unique across all
Salesforce, not just yours).

In **both** orgs:

- Setup → Business Hours → edit the default: Mon–Fri 09:00–18:00, your time zone. A new org's
  default is 24/7, which makes every business-hours calculation equal clock time.
- Setup → Users → create `CI Integration` (one of the two Salesforce licences), profile
  System Administrator. In a real project this user gets a deploy-only permission set; in a
  Developer Edition org System Administrator is the practical option — say so in the lecture.

In **`fde-prod` only**: Setup → Dev Hub → Enable Dev Hub.

## 2. Authorise locally

```bash
sf org login web --alias fde-prod --set-default-dev-hub
sf alias set fde-devhub=<fde-prod username>
sf org login web --alias fde-test
sf config set target-org=fde-test   # never fde-prod as the default
```

## 3. JWT for CI

Certificate and key, once, outside the repo:

```bash
mkdir -p ~/fde-ci && cd ~/fde-ci
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
  -keyout server.key -out server.crt -subj "/CN=fde-ci"
```

In **each** org (you): Setup → External Client App Manager → New:

- OAuth enabled; callback `http://localhost:1717/OAuthRedirect`
- Scopes: `api`, `refresh_token, offline_access`, `web`
- Flow enablement: **JWT Bearer Flow**, upload `server.crt`
- Policies: Permitted users = *Admin approved users are pre-authorized*; add the System
  Administrator profile (or a permission set assigned to `CI Integration`)
- Copy the **Consumer Key**

Check each from your terminal before touching GitHub:

```bash
sf org login jwt --client-id <consumer key> --username <ci integration username> \
  --jwt-key-file ~/fde-ci/server.key --instance-url https://login.salesforce.com --alias ci-check-test
sf org logout --target-org ci-check-test --no-prompt
```

## 4. GitHub (you)

Repos in the EPAM GitHub org: `brightline-support` (this project) and `sf-sdlc-plugins`.

If `gh` is logged in to another account: `gh auth login` adds a second one; `gh auth switch`
picks it. Check `gh auth status` before every push.

In `brightline-support` → Settings:

| Where | What |
|---|---|
| Environments → `test` | vars `SF_CLIENT_ID`, `SF_USERNAME`, `SF_INSTANCE_URL` (`https://login.salesforce.com`); secret `SF_JWT_KEY` (contents of `server.key`) |
| Environments → `prod` | the same for `fde-prod`; **Required reviewers: you** — the last human gate before production |
| Secrets → Actions | `ANTHROPIC_API_KEY` for the AI review job |
| Branches → `test`, `main` | require a PR; require status checks `static` and `validate`; no direct pushes, no force-push |
| Labels | `feature`, `bug`, `permissions-reviewed` |

## 5. Seed the orgs

```bash
git switch main && sf project deploy start --source-dir force-app --target-org fde-prod --test-level RunLocalTests
git switch main && sf project deploy start --source-dir force-app --target-org fde-test --test-level RunLocalTests
git switch test && sf project deploy start --source-dir force-app --target-org fde-test --test-level RunLocalTests
```

After this, `BusinessHoursCalculator` (GH-1) is in `fde-test` and not in `fde-prod` — the setup the
deploy-preflight demo needs. Create issue GH-1 ("Business hours helper", closed) so the number in
`CLAUDE.md` is real.

These three deploys are done by you, by hand, once. From here on, only CI deploys to these orgs.

## 6. Plugin

From `brightline-support/`, start Claude Code and trust the folder: `.claude/settings.json` declares
the `fde-sdlc` marketplace and enables `sf-sdlc`. Or explicitly:

```bash
claude plugin marketplace add ../sf-sdlc-plugins
claude plugin install sf-sdlc@fde-sdlc
```

Once `sf-sdlc-plugins` is on GitHub, change the marketplace source in `.claude/settings.json` to
`{"source": "github", "repo": "<epam-org>/sf-sdlc-plugins"}`.

Check: `/plugins` lists `sf-sdlc`; `/agents` lists the nine `sdlc-*` agents; asking the agent to run
`sf project deploy start --target-org fde-test --source-dir force-app` is blocked by the guard.

## 7. Dry run

```text
/sf-sdlc:architect-flow docs/demo/01-meeting-notes.md
/sf-sdlc:dev-workflow <issue number>
```

Then the promotion: open a PR from the feature branch's commits onto `main` (see
`docs/demo/runbook.md`) and watch `validate` fail on `BusinessHoursCalculator` — the failure the
preflight predicted.
