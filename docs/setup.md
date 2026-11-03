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

No Dev Hub is needed: the agent builds in `fde-test` directly.

## 2. Authorise locally

```bash
sf org login web --alias fde-prod
sf org login web --alias fde-test
sf config set target-org=fde-test   # never fde-prod as the default
```

Put `fde-test`'s instance URL (Setup → My Domain, e.g. `https://<name>-dev-ed.develop.my.salesforce.com`)
into the Orgs table in `CLAUDE.md`. It is not a secret; the agent uses it to open record pages.

## 2b. Claude access

Use an **EPAM-provided** Claude credential for both the local session and CI. Not a client one: in
the daily profile `ANTHROPIC_BASE_URL` points at a client AI gateway, which would route and bill the
lecture through the client. In the demo profile check:

```bash
env | grep -E '^ANTHROPIC_|^CLAUDE_CODE_USE_' | cut -d= -f1   # names only; expect nothing client-specific
claude auth status
```

For CI, store **one** of these as a repository secret: `ANTHROPIC_API_KEY` (an API key) or
`CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`, tied to the person who generated it).

## 2c. Browser for the in-org check

```bash
npx -y @playwright/mcp@0.0.83 --help >/dev/null && echo ok
```

Start Claude Code in `brightline-support/`, approve the `playwright` server, ask it to open the
`fde-test` login page, and log in by hand once. The profile persists, so the agent later reuses the
session without ever seeing the password or a session URL.

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
| Secrets → Actions | `ANTHROPIC_API_KEY` **or** `CLAUDE_CODE_OAUTH_TOKEN` for the AI review job (step 2b) |
| Actions → General | Actions enabled; `anthropics/claude-code-action` allowed if the org restricts third-party actions |
| Branches → `test`, `main` | require a PR; require status checks `static` and `validate`; no direct pushes, no force-push. The first PR must run once before GitHub offers the check names |
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

The project does **not** auto-enable the plugin, so installing it is a step in the demo:

```text
/plugin marketplace add <epam-org>/sf-sdlc-plugins
/plugin install sf-sdlc@fde-sdlc
/reload-plugins
```

Check: `/plugins` lists `sf-sdlc`; `/agents` lists the nine `sdlc-*` agents; asking the agent to run
`sf project deploy start --target-org fde-prod --source-dir force-app` is blocked by the guard.
Uninstall again before the lecture (`/plugin uninstall sf-sdlc@fde-sdlc`) so the live install is real.

For a team, the same install goes into `.claude/settings.json` as `extraKnownMarketplaces` +
`enabledPlugins`, and everyone who trusts the folder is prompted to install it — show that on a
slide, not live.

## 7. Dry run

```text
/sf-sdlc:architect-flow docs/demo/01-meeting-notes.md
/sf-sdlc:dev-workflow <issue number>
```

Then the promotion: open a PR from the feature branch's commits onto `main` (see
`docs/demo/runbook.md`) and watch `validate` fail on `BusinessHoursCalculator` — the failure the
preflight predicted.
