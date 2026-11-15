# Walkthrough — GH-2 end to end, and how each part works

This is the presenter's reference. It takes the base feature **GH-2, first-response SLA** (from
[01-meeting-notes.md](01-meeting-notes.md)) through the whole pipeline: plugin → issue → plan →
build in a scratch org → review → PR → CI → QA org → release to production. Every step says what
runs, how it works, which layer enforces it and where you can show it. Do this as the dry run
before the rehearsal: the live task GH-3 uses exactly the same steps.

- Gate answers: [runbook — Gate answer key](runbook.md#gate-answer-key). Answer the same way every
  run, so the test plan stays valid.
- What "correct" means for GH-2 in the org: [test-plan.md §2](test-plan.md#2-gh-2--first-response-sla).
- One-time environment setup: [setup.md](../setup.md).

Paths starting with `sf-sdlc-plugins/` are in the plugin repo, a sibling checkout of this one
(`../sf-sdlc-plugins` from the repo root). `P/` below means `sf-sdlc-plugins/plugins/sf-sdlc/`.
`<n>` is the GH-2 issue's real number. GitHub hands it out, and issues and PRs share one counter.

---

## 1. The moving parts

| Part | What it is | Who may change it |
|---|---|---|
| `so-GH-<n>` | Scratch org for one task, 7 days, created by [scripts/scratch-create.sh](../../scripts/scratch-create.sh) from the Dev Hub | the agent: deploys, data, tests |
| `fde-test` | QA scratch org, long-lived (≤ 30 days, then recreated by a human) | CI only, on merge to `test` |
| `fde-prod` | Developer Edition org: production **and** Dev Hub | CI only, on merge to `main`, after the required reviewer |
| `brightline-support` | This repo (public): `force-app/`, `sdlc/GH-<n>/` artifacts, CI, scripts | the agent on a feature branch; `test` and `main` only through PRs |
| `sf-sdlc-plugins` | Plugin marketplace (private), one plugin `sf-sdlc` | you |
| Branches | `feature/GH-<n>-<slug>` from `test` → PR to `test` → release PR `test` → `main` | the agent pushes the feature branch; a human merges |
| Worktree | `.claude/worktrees/GH-<n>`: a separate checkout per task (git-ignored) | the agent creates it; you remove it |

**Plugin `sf-sdlc`** (`P/`):

| Kind | Name | Job |
|---|---|---|
| Skills you start | `architect-flow`, `dev-workflow` | the two orchestrators. They run in the main session, because a gate is a question to you and subagents cannot ask one |
| Skills they call | `issue-context`, `issue-write`, `security-review`, `process-log`, `artifact-contract` | GitHub issue I/O, security passes, the defect log, the file rules |
| Agents | `sdlc-architect`, `sdlc-planner`, `sdlc-plan-verify`, `sdlc-impl-admin`, `sdlc-impl-apex`, `sdlc-impl-lwc`, `sdlc-tests`, `sdlc-reviewer` | one per stage, each with its own `tools:` line |
| Hook | `guard.sh` on PreToolUse → Bash | checks every shell command before it runs |
| Scripts | `verify-plan.sh`, `list-metadata.sh`, `process-log.sh` | checks and outputs with no model and no tokens |

**CI** ([.github/workflows/](../../.github/workflows/)):

| Workflow | Trigger | Jobs |
|---|---|---|
| [pr-validate.yml](../../.github/workflows/pr-validate.yml) | PR to `test` or `main` | `static` (Jest, Code Analyzer, risk scan) → `validate` (check-only deploy + local tests against the target org) |
| [ai-review.yml](../../.github/workflows/ai-review.yml) | PR opened or updated | `review`: Claude Code reads the diff, posts one comment. No Salesforce secret |
| [deploy.yml](../../.github/workflows/deploy.yml) | push to `test` or `main` (that is, a merge) | quick-deploys the job the PR validated; full deploy if there is none |

---

## 2. Settings tour — where to open and show each thing

### Hooks

| Show | Where | What to point at |
|---|---|---|
| The hook is registered | `/hooks` in a Claude Code session | `PreToolUse` → matcher `Bash` → `bash "${CLAUDE_PLUGIN_ROOT}/hooks/guard.sh"` |
| The registration file | `P/hooks/hooks.json:3-13` | one command hook, matcher `Bash`. It runs for every Bash call, including those of subagents |
| The rules | `P/hooks/guard.sh` | `:10` agent orgs = `^so-.+$` · `:24-31` deploys and data writes need a named `so-*` org · `:35-38` scratch orgs only with alias `so-*` · `:41-43` no destructive changes, no org deletion · `:46-56` no token-printing commands, no human-only scripts · `:59-64` no force-push, no push to `main`/`test`, no merge, no `gh api` writes, no secret/variable writes |
| How it decides | `guard.sh:11` reads the call as JSON from stdin (`.tool_input.command`) · `:14` `block()` prints the reason to stderr and exits **2** | exit 2 = Claude Code does not run the command and hands the reason to the model; exit 0 = it runs |
| It works | `bash ../sf-sdlc-plugins/plugins/sf-sdlc/hooks/guard.test.sh` | 35 cases. Each feeds the hook the same JSON Claude Code sends and checks the exit code. Ends with `35 passed, 0 failed` |

**The hook's limit.** It sees the command line, not what a script does inside it.
`bash scripts/scratch-create.sh GH-<n>` passes the guard, even though the script runs
`sf org create`, `sf project deploy` and `sf org assign` internally. The repo makes up for that in
two ways:
- The agent may run only scripts that are safe whatever they are given. `scratch-create.sh`
  hard-codes alias `so-<name>` and only reads `fde-test`/`fde-prod`.
- The scripts that hand out a session or a credential are blocked by name (`guard.sh:55`):
  `scratch-login.sh`, `fde-test-create.sh` and `fde-test-ci-auth.sh` are for humans only.

### Permissions (harness)

[.claude/settings.json](../../.claude/settings.json), enforced by Claude Code itself:

| Rule | Lines | Effect |
|---|---|---|
| `deny` Read of `.env*`, `.sf/**`, `.sfdx/**`, `~/.sf/**`, `~/.sfdx/**`, `**/*.key` | 3-10 | the agent cannot open stored org logins or the CI key |
| `deny` `sf org login jwt`, `sf org logout` | 11-12 | it cannot log in to or out of orgs |
| `ask` `git push`, `gh pr create`, `gh issue create`, `gh issue edit` | 14-19 | a permission prompt before anything leaves the machine: the "L7 push" moment |
| `enabledMcpjsonServers: ["playwright"]` | 21 | the browser tool from `.mcp.json` is enabled for the project |

### Agent tool limits (harness)

Open each agent file; the `tools:` line in the front matter is what the harness enforces.

| Agent | `tools:` | Consequence |
|---|---|---|
| `sdlc-reviewer` | `Read, Grep, Glob` | cannot edit, write or run anything; returns text that the workflow appends to `30-review.md` |
| `sdlc-plan-verify` | `Read` | judges the plan as written: no search, no shell |
| `sdlc-architect`, `sdlc-planner` | `Read, Grep, Glob, Bash, Write` | no Edit; Bash goes through the guard |
| `sdlc-impl-admin`, `-apex`, `-lwc`, `sdlc-tests` | `Read, Grep, Glob, Bash, Write, Edit` | build and deploy; Bash goes through the guard, so deploys reach `so-*` only |

Skill front matter that the harness also reads:
- `disable-model-invocation: true` on `architect-flow` and `dev-workflow`: only you can start them,
  with `/sf-sdlc:…`.
- `context: fork` plus `disallowed-tools: Edit, NotebookEdit` on `security-review`: it runs in its
  own context, without Edit.
- `allowed-tools` on `issue-context`, `issue-write` and `process-log` **pre-approves** those
  commands while the skill runs. It does not restrict anything.

`/agents` lists the eight agents. Open one to show its tools.

### Browser (MCP)

[.mcp.json](../../.mcp.json) starts `@playwright/mcp@0.0.83`, pinned, through `npx`. The browser
profile persists between sessions. You log it in to each scratch org once with
`scratch-login.sh`. The agent never holds a credential: it gets the address from
[scripts/org-url.sh](../../scripts/org-url.sh), which prints the instance URL only.

### CI settings (GitHub)

| Show | Where |
|---|---|
| Environments | Settings → Environments → `prod`: **required reviewer** (you); variables `SF_CLIENT_ID`, `SF_USERNAME`, `SF_INSTANCE_URL`; secret `SF_JWT_KEY` · `test`: secret `SF_AUTH_URL` only |
| Why two login methods | `pr-validate.yml:51-67`, `deploy.yml:28-44`: if `SF_AUTH_URL` is set (test), log in with the auth URL; otherwise JWT (prod). The External Client App exists only in `fde-prod`, so JWT cannot reach a scratch org |
| Which environment a job uses | `pr-validate.yml:40` and `deploy.yml:18`: `main` → `prod`, otherwise `test`. That single line decides which org and which secrets |
| Claude credentials | one repository secret, `CLAUDE_CODE_ENV` (a JSON object of environment variables). Read only by `ai-review.yml`'s review step, which masks every value before exporting it |
| Required checks | Settings → Branches → rules for `test` and `main`: PR required, `static` and `validate` must pass, branch up to date, no bypass, no force-push |
| Fork PRs | Settings → Actions → General: approval required for all external contributors. `ai-review.yml:21` also skips forks and drafts |
| Labels | `permissions-reviewed`, read by the risk scan (below) |

### Scripts

| Script | Purpose | Run by |
|---|---|---|
| [scratch-create.sh](../../scripts/scratch-create.sh) `<name> [days=7]` | reads the Business Hours time zone (`:29-35`, before any slot is spent) → creates `so-<name>` (`:41`) or reuses it (`:37`) → Business Hours (`:46`) → deploys the checkout (`:50`) → `Support_Agent` if not assigned (`:52-56`) → prints alias, username, instance URL, expiry | Stage 0 (agent) or you |
| [set-business-hours.sh](../../scripts/set-business-hours.sh) `<alias> [tz]` | REST PATCH of the default `BusinessHours` (Apex cannot update it): Mon–Fri 09–18, weekend empty | `scratch-create.sh`, `fde-test-create.sh` |
| [scratch-login.sh](../../scripts/scratch-login.sh) `<alias>` | one-time login URL to the clipboard (`pbcopy`), scratch orgs only | **you only**: the guard blocks it |
| [org-url.sh](../../scripts/org-url.sh) `<alias>` | instance URL only. The agent's way to address an org without `sf org display` or `sf org list --json`, which print tokens | agent |
| [fde-test-create.sh](../../scripts/fde-test-create.sh), [fde-test-ci-auth.sh](../../scripts/fde-test-ci-auth.sh) | create the QA org; store its auth URL as the `test` secret | **you only**: blocked |
| [scripts/ci/risk-scan.sh](../../scripts/ci/risk-scan.sh) | hardcoded IDs in added lines (`:14-17`); assertion count per modified test class must not drop (`:20-24`); permission files changed without the `permissions-reviewed` label (`:27-34`) | CI, in `static` |
| `P/scripts/verify-plan.sh <dir>` | structure of `10-plan.md`: sections, Yes/No classification matches the task types, every AC mapped, every path exists or is marked `(new)`, a Verify line | the planner, on itself |
| `P/scripts/list-metadata.sh <base> <out> [org]` | git diff → components by type → `35-metadata.md`, plus a validate command it **prints, never runs** | Stage 5 |
| `P/scripts/process-log.sh add\|check` | append-only defect log; validates the category; `check` groups rows by component | the workflow, on rework |

---

## 3. Which layer enforces which promise

| Promise | Layer | Where |
|---|---|---|
| The agent deploys and writes data only in `so-*` | **hook** | `guard.sh:24-31` |
| No token, auth URL or session reaches the context | **hook** + **harness** | `guard.sh:46-56`; settings `deny` on `.sf/**`, `*.key` |
| No force-push, no push to `main`/`test`, no merge | **hook** | `guard.sh:59-61` |
| `test` and `main` change only through a green PR | **CI** | branch rules: required `static` + `validate` |
| Production deploy waits for a person | **CI** | environment `prod`: required reviewer |
| The reviewer cannot edit what it reviews | **harness** | `sdlc-reviewer` `tools: Read, Grep, Glob` |
| A push or PR asks you first | **harness** | settings `ask` |
| The plan has every section, every AC mapped, real paths | **script** | `verify-plan.sh`, run by the planner |
| The process log is append-only | **script** | `process-log.sh`: no code path edits a row |
| Hardcoded IDs, weakened tests, unreviewed permission changes block the merge | **script in CI** | `risk-scan.sh` in `static` |
| Business Hours are set in every task org | **script** | `scratch-create.sh:46`, as long as the org was created by it (the guard blocks other ways for the agent) |
| The three approval gates; the two-round loop caps; "one writer per file"; "verbatim" in `00-context.md`; the architect does not change orgs | **instruction** | the skills' and agents' text. Nothing checks it |
| The AI review job has nothing to steal | **CI config** | `ai-review.yml`: no Salesforce secret, `--allowedTools` list, `permissions: pull-requests: write` only |

The last instruction row is the lecture's point: the gates hold because the model follows the
skill, not because something stops it. If a script can detect something, it belongs in a hook, a
script or CI.

---

## 4. The run

Start Claude Code **in a terminal** (`claude`) in `brightline-support/`, on an up-to-date `test`.
The VS Code extension has no `/plugin`. Plugin installed (setup §9), `/clear`ed. Keep a second,
private terminal open for `scratch-login.sh`.

### Step 1 — Check the toolkit

- **Do:** `/agents`, then `/hooks`.
- **What runs:** nothing; Claude Code lists what the plugin registered.
- **How it works:** one install brought eight agents, the skills and one hook. The hook entry
  comes from `P/hooks/hooks.json`; `${CLAUDE_PLUGIN_ROOT}` points at the installed plugin.
- **Enforced by:** harness (the plugin loader).
- **Where to show it:** `/agents` (open `sdlc-reviewer` → tools), `/hooks` → PreToolUse.
- **Check:** eight `sdlc-*` agents; the guard under PreToolUse → Bash.
- **If it fails:** `claude plugin list` must show `sf-sdlc@fde-sdlc`, version 0.2.0 or later,
  enabled, scope local. Then `/reload-plugins`.

### Step 2 — Raw notes → draft (architect)

- **Do:** `/sf-sdlc:architect-flow docs/demo/01-meeting-notes.md`
- **What runs:** skill `architect-flow` → agent `sdlc-architect` (Mode A).
- **How it works:**
  1. The architect lists every requirement, number and ambiguity in the notes.
  2. It researches before it asks: it reads the repo (`CaseTrigger`, `CaseTriggerHandler`,
     `BusinessHoursCalculator`, `Customer_Tier__c`, the `Escalations` queue) and queries
     `fde-test` read-only (`sf sobject describe`, `sf data query`).
  3. Only what research cannot settle becomes an open question, each with a proposed default.
  4. It writes `sdlc/DRAFT-<date>-<slug>/14-ticket-draft.md` with Given/When/Then AC, a Solution
     Design, Test Notes, Out of scope, Open questions and Findings for upstream.
- **Enforced by:** instruction ("research before you ask", "every number lands in an AC or Out of
  scope", "never change an org"). The hook adds a hard floor: a write to `fde-test` would be
  blocked anyway (`guard.sh:24-31`).
- **Where to show it:** `P/agents/sdlc-architect.md` (Mode A steps 1–5); the draft file.
- **Check:** the draft names `BusinessHoursCalculator`, `Customer_Tier__c` and `Escalations`
  without having asked about them. Each number from the notes (2/8/24 h, "half", ~5k) appears in an
  AC or in Out of scope.
- **If it fails:** if it asked about something the repo answers, log a `process-log` row
  (`input-gap` or `rework`, about `sdlc-architect`).

### Step 3 — Gate A, then the issue

- **Do:** answer the open questions from the [answer key](runbook.md#gate-answer-key) →
  `approve`. Then `issue-write` shows the exact body and asks `Create this issue?` → `yes`. You
  also get the harness `ask` prompt for `gh issue create`.
- **What runs:** `architect-flow` step 2 (Gate A, at most two change rounds) → skill
  `issue-write`: marker search (`gh issue list --search "in:body sdlc-draft:<id>"`) → `gh issue
  create --body-file`.
- **How it works:** Gate A is a question in the main session. Answers go back to the architect,
  which overwrites the draft. `issue-write` copies the draft's marker comment into the issue body,
  so a rerun finds the issue and edits it instead of creating a duplicate.
- **Enforced by:** Gate A and the "show, then ask once more" step are **instruction**. The
  `gh issue create` permission prompt is **harness** (`settings.json:17`).
- **Where to show it:** `P/skills/architect-flow/SKILL.md` §2–3; `P/skills/issue-write/SKILL.md`
  §1–2; the issue on GitHub (sections Business need, Acceptance Criteria, Solution Design, Test
  Notes, Out of scope).
- **Check:** the issue exists; every Gate A answer is visible in an AC or in Out of scope.
- **If it fails:** creation fails partway (a missing label, for example) → `issue-write` reports
  what was and wasn't created. Don't retry without the marker check.

### Step 4 — Hand-over: context, design, security design pass

- **Do:** nothing; `architect-flow` step 4 continues on its own.
- **What runs:**
  1. skill `issue-context <n>` → `gh issue view --json` → `sdlc/GH-<n>/00-context.md`
  2. `sdlc-architect <n> design` → `15-design.md`
  3. skill `security-review design GH-<n>` (forked) → `55-security.md`
  4. plain `mv` of the draft into `sdlc/GH-<n>/` (nothing is committed yet; the folder stays
     untracked in the main checkout until Stage 0 moves it into the worktree)
- **How it works:** `00-context.md` copies the AC and the design **verbatim**. Every later stage
  quotes AC ids from it, so a paraphrase would be a silent requirement change. `15-design.md`
  holds the decisions the planner must not re-make: fields, sharing, Flow vs Apex, bulk. The
  security design pass asks who runs it, who sees what, and what leaves the org. A RED verdict
  stops before planning.
- **Enforced by:** instruction (verbatim, one writer per file:
  `P/skills/artifact-contract/SKILL.md`). The forked context and the removed Edit tool are
  harness (`security-review` front matter).
- **Where to show it:** `sdlc/GH-<n>/00-context.md`, `15-design.md`, `55-security.md` (design
  pass); the artifact table in `artifact-contract/SKILL.md`.
- **Check:** `00`, `14`, `15` and `55` exist in `sdlc/GH-<n>/`; `55` is not RED.
- **If it fails:** a RED security verdict stops here; answer it with the architect before planning.

### Step 5 — Stage 0: worktree and scratch org

- **Do:** `/sf-sdlc:dev-workflow <n>`
- **What runs:**
  1. `dev-workflow` Stage 0 checks that no **tracked** file is modified
     (`git status --porcelain --untracked-files=no`); untracked files, like the architect's
     `sdlc/GH-<n>/`, are fine.
  2. `git fetch origin && git worktree add .claude/worktrees/GH-<n> -b feature/GH-<n>-<slug>
     origin/test`; it moves the architect's `sdlc/GH-<n>/` into the worktree, so the design travels
     with the branch; then the `EnterWorktree` tool moves the session in.
  3. `bash scripts/scratch-create.sh GH-<n>` runs in the background.
- **How it works:** each task gets its own checkout and its own org, so two tasks never deploy
  over each other. The branch starts from `test`, because that is what `fde-test` holds. The
  script reads the time zone first, then creates `so-GH-<n>` for 7 days from `fde-prod`, sets
  Business Hours **before** anything runs tests, deploys the worktree and assigns
  `Support_Agent`. Planning doesn't need the org, so the minutes of creation overlap with Gates 1
  and 2.
- **Enforced by:** guard: the agent can create a scratch org only with alias `so-*`
  (`guard.sh:35-38`) and cannot delete one (`:43`). Script: `scratch-create.sh` hard-codes the
  alias and the order. Instruction: "check the background job before Stage 3".
- **Where to show it:** `P/skills/dev-workflow/SKILL.md` Stage 0; `scripts/scratch-create.sh`;
  `git worktree list`; later `sf org list`, which shows `so-GH-<n>` as Scratch with an expiry.
- **Check:** the worktree is listed. The background output ends with `so-GH-<n> is ready.` and
  the summary. Write down the minutes it took.
- **If it fails:**
  - "working tree is dirty": a tracked file is modified in the main checkout. Commit or stash it,
    then rerun.
  - A creation error: show the last lines; a rerun creates nothing and finishes the setup steps.
  - Slots: `sf org list limits --target-org fde-prod | grep -i scratch`.

**You, in the private terminal**, once the org is ready: `bash scripts/scratch-login.sh
so-GH-<n>` → paste the URL into the Playwright window → the org's home page. The guard blocks this
script for the agent (`guard.sh:55`), because the URL carries a live session.

### Step 6 — Gate 1: the requirements

- **Do:** read the AC and the findings shown → `approve`.
- **What runs:** `dev-workflow` Stage 1 (it runs `issue-context` only if `00-context.md` is
  missing).
- **How it works:** nothing is planned on requirements you have not seen. Gate 1 shows the AC
  section and the `Findings for upstream` block.
- **Enforced by:** instruction.
- **Where to show it:** `dev-workflow/SKILL.md` Stage 1; `sdlc/GH-<n>/00-context.md`.
- **Check:** the AC match the issue word for word.
- **If it fails:** a wrong AC → fix the issue (architect), then rerun `issue-context`.

### Step 7 — Plan, structural check, semantic check

- **Do:** wait.
- **What runs:**
  1. agent `sdlc-planner` writes `10-plan.md`, then runs `bash
     "${CLAUDE_PLUGIN_ROOT}/scripts/verify-plan.sh" sdlc/GH-<n>` and fixes until it passes
  2. agent `sdlc-plan-verify` (Read only) → `VERDICT: PASS | REVISE`
  3. on REVISE: the planner revises, keeping `10-plan.r<N>.md`, up to two rounds, each logged with
     `process-log` (`rework`)
- **How it works:** the split is the lesson.
  - `verify-plan.sh` checks what a script can check, for zero tokens: the four sections, Yes/No
    for Admin/Apex/LWC agrees with the task types, every `AC<n>` from `00-context.md` appears in
    the AC Mapping, every `force-app/…` path exists or is marked `(new)`, a `Verify:` line exists.
  - `sdlc-plan-verify` judges only what a script can't: would the mapped tasks really make each AC
    true, does each negative AC have a test, is each task buildable from its Spec line, does the
    plan respect `15-design.md`.
- **Enforced by:**
  - script: the checks themselves, once run
  - instruction: that the planner runs the script and returns only a passing plan, and the
    two-round cap
  - harness: the verifier can't search or run anything
- **Where to show it:** `P/scripts/verify-plan.sh` (sections `:17-19`, classification `:21-29`,
  AC mapping `:32-37`, paths `:40-49`); run it yourself: `bash
  ../sf-sdlc-plugins/plugins/sf-sdlc/scripts/verify-plan.sh sdlc/GH-<n>`;
  `P/agents/sdlc-plan-verify.md`.
- **Check:** the script ends with `PASS`; the verifier's verdict is `PASS`.
- **If it fails:** after two REVISE rounds the workflow stops and shows you the open findings.
  That's your call.

### Step 8 — Gate 2: the plan

- **Do:** check against the [Gate 2 key](runbook.md#gate-answer-key):
  - multipliers and targets in **custom metadata**
  - respond-by time set on insert and on a priority or tier change
  - escalation as a scheduled job that can also be started on demand

  Then `approve`, or `change <what>`.
- **What runs:** `dev-workflow` Stage 2 shows the Work Classification, the task list, the AC
  Mapping and the verdict.
- **How it works:** you review the plan, not the diff. Changing a task here costs one revision;
  after the build it costs a fix loop. The classification is the only machine-read signal that
  decides which builders run.
- **Enforced by:** instruction.
- **Where to show it:** `sdlc/GH-<n>/10-plan.md` (`## Work Classification`, `## AC Mapping`).
- **Check:** every AC maps to a task and a test; nothing hardcodes 2/8/24 or the multipliers.
- **If it fails:** `change` with the key's wording; the planner writes a `## Revision <N>`
  section.

### Step 9 — Build in `so-GH-<n>`

- **Do:** wait. Before this stage the workflow confirms that the background job printed `ready`.
- **What runs:** in plan order, only the types marked Yes: `sdlc-impl-admin` → `sdlc-impl-apex` →
  `sdlc-impl-lwc`, then `sdlc-tests` if non-test Apex changed. Each gets `GH-<n>` and the plan path.
- **How it works:**
  - **Admin** builds fields, custom metadata, permission set entries and flows, then `sf project
    deploy start --target-org so-GH-<n> --source-dir <paths>` until it deploys clean.
  - **Apex** follows `CLAUDE.md`: one trigger per object, `CaseTriggerHandler`, sharing declared,
    user mode, no SOQL in loops, configuration in custom metadata. It lists its public methods
    under `### Public surface` in `20-impl-notes.md`.
  - **LWC** binds only to that surface. It runs Jest, deploys, then checks the page in the browser
    at `$(bash scripts/org-url.sh so-GH-<n>)/lightning/r/Case/<id>/view` and saves
    `sdlc/GH-<n>/lwc-<component>.png`.
  - **Tests** writes assertions from the AC, not from the code: a 251-record bulk test, a negative
    test per negative AC, and `runAs` with a `Support_Agent` user. Then the inversion check: flip
    one rule in the code, see the test fail, revert.
- **Enforced by:**
  - hook: every deploy and data write must name a `so-*` org (`guard.sh:24-31`); `sf org open` is
    blocked (`:51`)
  - harness: the tools lines
  - instruction: the build order, "a failed deploy is fixed, not reported", the inversion check
- **Where to show it:** `P/agents/sdlc-impl-*.md`, `P/agents/sdlc-tests.md`;
  `sdlc/GH-<n>/20-impl-notes.md` (one section per agent), `25-tests.md` (inversion table),
  `lwc-*.png`.
- **Check:** `20` has a section per agent that ran; `25` shows all tests passing and an inversion
  table; the screenshot exists.
- **If it fails:**
  - A login screen in the browser → the LWC agent stops and asks you to run `scratch-login.sh`.
  - An implementer that can't fix a failure stops the stage and shows you.
  - Business-hours results equal to clock time → check the org's Business Hours (CLAUDE.md
    landmine).

### Step 10 — Review and fix loop, security build pass

- **Do:** wait.
- **What runs:** agent `sdlc-reviewer` → its text is appended **unchanged** to `30-review.md` →
  on `Fix loop required`, each defect goes to its owner stage, then review again (at most two
  rounds, logged) → skill `security-review build GH-<n>`, forked, which runs `sf code-analyzer run
  --rule-selector Security` and appends a verdict to `55-security.md`.
- **How it works:** the reviewer runs in its own context: it did not write the code, and it can
  only read. Every finding must quote a file and line, with a severity and an owner stage. It
  checks AC coverage, design fit, undeclared deviations, test quality and mixed-batch logic. The
  security build pass checks sharing, user mode, permission-set-only grants, injection, secrets and
  guest paths. It can't be GREEN with an unaddressed Code Analyzer security violation.
- **Enforced by:** harness (the reviewer can't edit; security runs forked, without Edit);
  instruction (the scribe rule "do not soften", the two-round cap).
- **Where to show it:** `P/agents/sdlc-reviewer.md`, `P/skills/security-review/SKILL.md`;
  `sdlc/GH-<n>/30-review.md` (AC Coverage table, Defects, Verdict), `55-security.md` (build pass).
- **Check:** `30` ends with `Ready for human review`; the `55` build pass is GREEN, or RED with
  findings you'll take to Gate 3.
- **If it fails:** after two fix rounds the open defects come to you.

### Step 11 — Metadata list

- **Do:** wait.
- **What runs:** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/list-metadata.sh" origin/test
  sdlc/GH-<n>/35-metadata.md fde-test`
- **How it works:** a `git diff` against `origin/test`, mapped to metadata types. Deleted files go
  in their own "needs destructiveChanges, a human decision" section. The file ends with a
  `sf project deploy validate --target-org fde-test …` command that the script **prints and never
  runs**. Validate is check-only, so the guard allows it if anyone does run it.
- **Enforced by:** script.
- **Where to show it:** `P/scripts/list-metadata.sh`; `sdlc/GH-<n>/35-metadata.md`.
- **Check:** every new field, class, CMDT record, the LWC and the permission set are listed; no
  `UNMAPPED` rows.
- **If it fails:** an `UNMAPPED` path is reported under Findings for upstream.

### Step 12 — Gate 3, then commit, push, PR

- **Do:** read the Gate 3 summary → `approve`. **Approve the `git push` prompt and the `gh pr
  create` prompt.**
- **What runs:** `dev-workflow` Gate 3 shows the `30` verdict and AC table, the `55` verdict, the
  `25` results, the `35` list and any Discussion items → Stage 6: `git add force-app sdlc/GH-<n> &&
  git commit` → `git push -u origin HEAD` → `gh pr create --base test --body "Closes #<n>.
  Artifacts: sdlc/GH-<n>/"`.
- **How it works:** the artifacts travel with the PR, so the AI reviewer, the human reviewer and
  the customer read the same files the agents read. The push goes to the feature branch.
- **Enforced by:** harness: the `ask` prompts (`settings.json:15-16`). Hook: a push to `test` or
  `main`, a force-push and `gh pr merge` are blocked (`guard.sh:59-61`).
- **Where to show it:** the prompt on screen; `dev-workflow/SKILL.md` Stage 6; the PR's Files tab
  with `sdlc/GH-<n>/`.
- **Check:** the PR URL is reported; the PR targets `test`.
- **If it fails:** see the next step for the permission-set label.

### Step 13 — CI on the PR

- **Do:** Actions tab, or `gh pr checks <pr> --watch`.
- **What runs:**
  - `pr-validate.yml`:
    - `static`: `npm run test:unit` (Jest), Code Analyzer with `--severity-threshold 2`, then
      `risk-scan.sh origin/test <labels>`
    - `validate` (after `static`): environment `test` → login with `SF_AUTH_URL` →
      `sf project deploy validate --source-dir force-app --test-level RunLocalTests` against
      `fde-test` → uploads `validated-job-id`
  - `ai-review.yml`: `claude -p` with the prompt "review against REVIEW.md", `--allowedTools
    Read,Grep,Glob,Bash(git diff/log),Bash(gh pr diff/view/comment)` → one comment.
- **How it works:**
  - `validate` is a check-only deploy into the real QA org with all local tests. An invented field
    fails here, not in the org.
  - Its job ID is kept, so the merge can quick-deploy without running the tests again.
  - The review job has no Salesforce secret, and the only write its token allows is a PR comment.
    PR text is untrusted input, so a prompt injection finds nothing to steal.
- **Enforced by:** CI (required checks block the merge); CI config (the review job's
  permissions and tools).
- **Where to show it:**
  - the PR's Checks tab
  - `pr-validate.yml:14-34` and `:36-81`
  - `ai-review.yml:14-16` (permissions), `:49-54` (prompt and allowed tools)
  - [REVIEW.md](../../REVIEW.md) (what the AI checks, what it leaves alone, the format)
  - `gh run view <id> --log`
- **Check:** `static` and `validate` green; one AI comment in the REVIEW.md format.
- **If it fails:**
  - `static` fails with "permission metadata changed … add the 'permissions-reviewed' label": GH-2
    adds field permissions to `Support_Agent`, so this is expected, and the agent says so after
    opening the PR. **You** review the permission diff and add the label
    (`gh pr edit <pr> --add-label permissions-reviewed`); the label event reruns the checks. The
    guard blocks the agent from adding that label: it records a person's review.
  - `validate` red → read `jq` output in the log (component and test failures). Fix in the
    worktree, push, and checks rerun.
  - No AI comment → the job log shows a connection or auth error.

### Step 14 — Merge → deploy to `fde-test`

- **Do:** you merge the PR (merge commit). The agent can't: the guard blocks `gh pr merge`.
- **What runs:** `deploy.yml` on push to `test`, environment `test`:
  1. login with the auth URL
  2. find the merged PR → its head branch → the latest successful `pr-validate` run → download
     `validated-job-id` (`:45-57`)
  3. `sf project deploy quick --job-id` (`:58-62`)
  4. only if there is no usable job, or the quick deploy fails: a full deploy with tests (`:63-65`)
- **How it works:** the PR already validated the exact metadata against the same org, so the merge
  only commits that validation; the tests ran once. A validation expires, or goes stale if the org
  changed since, and then the full deploy takes over.
- **Enforced by:** CI.
- **Where to show it:** the `Deploy` run: step *Quick deploy the validated job* green, *Full
  deploy* skipped. `gh run watch $(gh run list --workflow deploy.yml --branch test --limit 1 --json
  databaseId --jq '.[0].databaseId')`.
- **Check:** green; then the smoke subset of [test-plan.md §2](test-plan.md#2-gh-2--first-response-sla)
  in `fde-test` (you run it: the agent can't write data there).
- **If it fails:** a full deploy failing means `fde-test` differs from what was validated. Read the
  component failures.

### Step 15 — Release to production

- **Do:** you: `gh pr create --base main --head test --title "Release: …"`. A release takes
  everything in `test`, so the helper (#3) travels with GH-2, which needs it.
- **What runs:** `pr-validate.yml` with environment **`prod`**. `validate` waits: approve it
  (PR → Checks → validate → *Review pending deployments* → `prod`). Login is JWT with the
  `CI Integration` user, then a check-only deploy against `fde-prod`. Merge → `deploy.yml` on
  `main` waits for `prod` again → approve → quick deploy.
- **How it works:** the same two workflows; the environment line switches the org and the
  secrets. You approve twice: before the production key reaches the validate job, and before the
  deploy. Cherry-picking GH-2 alone to `main` would fail validation with "Invalid type"
  (`BusinessHoursCalculator` isn't in production yet). That's why `CLAUDE.md` forbids it.
- **Enforced by:** CI (environment `prod` required reviewer; required checks on `main`).
- **Where to show it:** Settings → Environments → prod; the waiting run; `pr-validate.yml:40`,
  `deploy.yml:18`.
- **Check:** both runs green; in `fde-prod` a Gold, Medium case gets its respond-by time ([test
  plan](test-plan.md)).
- **If it fails:** a validation against `fde-prod` that fails on a missing type means something in
  the release isn't in `test`. Fix it in `test` first.

### Step 16 — Clean up and record

- **Do (you):**
  ```bash
  sf org delete scratch --target-org so-GH-<n> --no-prompt
  git worktree remove .claude/worktrees/GH-<n>
  sf org list limits --target-org fde-prod | grep -i scratch
  ```
  Write down the timings per stage, the org creation minutes and the issue and PR numbers.
  `process-log.sh check sdlc` prints any pipeline defects the run logged.
- **What runs:** nothing automatic: the guard blocks the agent from deleting orgs (`guard.sh:43`).
- **Where to show it:** `bash ../sf-sdlc-plugins/plugins/sf-sdlc/scripts/process-log.sh check sdlc`.
- **Check:** the active scratch-org count is back to where it started; `git worktree list` shows
  only the main checkout.
