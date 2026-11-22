# Demo walkthrough — one feature, start to finish

The only guide you need for the demo. It takes one small feature, the **tier priority floor and
badge**, from a raw Slack request to an open PR with green CI: plugin → issue → design → plan →
build in a scratch org → review → PR → CI. You run the same steps twice:

1. **Rehearsal** (before the lecture): Part A → Part B → Part C. Part C wipes everything the
   rehearsal created, so on the day nothing is already built.
2. **Live** (lecture day): Part D (checks) → Part B again, on screen.

Other files: the raw request [01-feature-request.md](01-feature-request.md) · what "correct" means
in the org [test-plan.md](test-plan.md) · one-time environment setup [setup.md](../setup.md) · the
slides [lecture-plan.md](../lecture/lecture-plan.md).

---

## How to read this guide

### Where you type

| Label | What it is |
|---|---|
| **Claude session** | Claude Code started **in a terminal** with `claude`, in `brightline-support/`, on branch `test`. Lines starting with `/` are typed here. Not the VS Code extension: it has no `/plugin` command |
| **Private terminal** | A normal terminal in `brightline-support/` that is **not** shared on screen. Used for the scratch-org login, because that command copies a live session to the clipboard |
| **Second Claude session** | Another `claude` in a terminal, only for the guard demo (step B10) |

### Placeholders

Everything in `<angle brackets>` is filled in during the run. Write each value down when it
appears.

| Placeholder | Meaning | Where you get it | Example |
|---|---|---|---|
| `<n>` | The **issue number** of the ticket. GitHub assigns it when the architect creates the issue | the issue URL printed at step B4: `…/issues/14` → `<n>` = `14` | `14` |
| `GH-<n>` | The task's name, used everywhere: folder `sdlc/GH-<n>/`, worktree, org, branch | built from `<n>` | `GH-14` |
| `so-GH-<n>` | The task's **scratch org** alias (`so` = scratch org) | created at step B6 | `so-GH-14` |
| `<slug>` | A few words from the issue title, chosen by the agent for the branch name | printed at step B6 | `priority-floor` |
| `feature/GH-<n>-<slug>` | The task's git branch | step B6 | `feature/GH-14-priority-floor` |
| `<pr>` | The **pull request number**. Issues and PRs share one counter, so it's a different number from `<n>` | printed at step B14 | `15` |
| `<r>` | The **rehearsal's** issue number. You need it for the reset (Part C) and the fallback | write `<n>` down during the rehearsal | `14` |
| `P/` | The installed plugin's folder in the plugin repo: `../sf-sdlc-plugins/plugins/sf-sdlc/` | — | `P/hooks/guard.sh` |

GitHub never reuses a number. Every run (rehearsal, live) gets a new `<n>`; that's expected.

### How each step is written

- **Do** — what you type, and where.
- **What it means** — every part of the command in plain words.
- **What happens** — what runs behind it.
- **You should see** — how you know it worked.
- **If it goes wrong** — the usual fix.

---

## The feature

Source: [01-feature-request.md](01-feature-request.md), a short Slack message from Lee.

- **Priority floor.** A Platinum customer's case is never below **High**; a Gold customer's case is
  never below **Medium**. Standard customers keep whatever priority they chose. The rule applies when
  a case is created and every time its priority or tier changes. If someone lowers it, the save
  quietly raises it back. It only ever raises.
- **Tier badge.** At the top of the Case page: a colored pill with the tier, plus a line
  `Minimum priority: High` (or Medium) explaining the floor.
- **Configuration, not code.** The tier → minimum priority mapping lives in custom metadata, so a
  business change is a record edit, not a deploy of Apex.

It touches every builder: Admin (custom metadata, record page), Apex (the trigger handler and a
small controller), LWC (the badge), plus tests, review and the browser check in the org.

### Gate answer key

Answer the gates the same way every run, so the result matches [test-plan.md](test-plan.md).

**Gate A** — the architect's open questions. You may not get every one; answer the ones you get:

| Question | Answer |
|---|---|
| Which tiers get which minimum? | Platinum → at least **High**; Gold → at least **Medium**; Standard → no minimum |
| When does the rule apply? | when a case is created, **and** whenever its priority or tier changes |
| Someone lowers a Platinum case to Low: error or raise? | quietly raise it back to the minimum on save, no error. The badge tells the agent why |
| Can an agent raise priority above the minimum? | yes. The rule only raises, never lowers (a Gold case on High stays High) |
| Existing cases? | **Out of scope**: no backfill |
| Integration or import user excluded? | no exception: the rule applies to every case |
| What does the badge show? | the tier as a colored pill (Platinum purple, Gold amber, Standard grey), and for Platinum and Gold a line `Minimum priority: <value>` read from the configuration |
| Where is the badge? | top of the Case record page, desktop. A new Case record page in source, activated as the org default, is fine |

Two things the architect should **not** ask, because the repo answers them: the tier field
(`Customer_Tier__c`, defaulted to Standard by `CaseTriggerHandler`) and where the mapping goes
(custom metadata, per `CLAUDE.md`). If it asks, answer, and log it afterwards (step C1).

**Gate 1** (requirements): `approve` if the AC match the issue word for word.

**Gate 2** (plan): steer with `change <what>` if the plan differs from this:
- the mapping is a custom metadata type with two records (Platinum → High, Gold → Medium); no
  priority value is hard-coded in Apex
- the logic is in `CaseTriggerHandler`: before insert (after the tier default), and before update
  only when priority or tier changed. No new trigger, no Flow
- the badge is an LWC that gets the minimum priority from a small cacheable Apex method;
  `Support_Agent` gets access to that class
- a Case record page with the badge, activated as the org default
- tests: one per tier, lowering on update, a tier change, a bulk insert of 200+, `runAs` a
  `Support_Agent` user

**Gate 3** (build): `approve` if the review says `Ready for human review`, security is GREEN, and
the in-org checks of [test-plan.md](test-plan.md) pass. Otherwise `change <what>`.

---

## Part A — Before you start

Do this before the rehearsal, off screen. On the live day it's part of Part D.

### A1 — Clean, up-to-date `test` checkout

- **Do** (private terminal):
  ```bash
  git switch test && git pull --ff-only
  git status --short
  ```
- **What it means:** switch to branch `test` and fast-forward it to GitHub's copy; then list
  changed files.
- **Why:** the task's branch is created from `origin/test`, and Stage 0 (B6) refuses to start if
  any **tracked** file is modified. Untracked files (`??`) are fine.
- **You should see:** no line starting with ` M`, `M ` or `D `.
- **If it goes wrong:** commit the change on a branch and open a PR to `test`, or `git stash`.
  Never commit to `test` directly. Keep your timing notes **outside** the repo, so they don't
  dirty it mid-run.

### A2 — Both permanent orgs are alive

- **Do** (private terminal): `sf org list`
- **What it means:** lists the Salesforce orgs this machine is logged in to.
- **You should see:**
  - `fde-prod`: `Connected`, marked 🌳. It's production **and** the Dev Hub, the org that hands
    out scratch orgs.
  - `fde-test`: `Active`, with an **Expires** date after the live day. It's the QA org CI validates
    against.
  - no `so-…` org left over from an earlier run.
- **If it goes wrong:**
  - `fde-test` expires before the live day → recreate it (setup §8, *Recreating `fde-test`*).
    That costs one daily scratch-org slot.
  - A leftover `so-…` org → `sf org delete scratch --target-org so-<name> --no-prompt`.

### A3 — Scratch-org limits

- **Do** (private terminal): `sf org list limits --target-org fde-prod | grep -i scratch`
- **What it means:** asks the Dev Hub how many scratch orgs you may still have. A Developer Edition
  Dev Hub allows **3 active** and **6 new per day**, and `fde-test` already holds one active slot.
- **You should see** (columns: Name, Remaining, Max):
  ```
  │ ActiveScratchOrgs   │ 2   │ 3   │
  │ DailyScratchOrgs    │ 6   │ 6   │
  ```
  You need **at least 2 Remaining** in both rows: one for the task's org, one spare in case
  creation fails.
- **If it goes wrong:** Active too low → delete leftover `so-…` orgs (A2). Daily too low → wait.
  The daily count resets 24 hours after each creation.

### A4 — Plugin: check, then uninstall

The plugin is installed **on screen** at step B1, so it must not be there beforehand. In the
rehearsal you practice exactly that install.

- **Do** (private terminal, in `brightline-support/`):
  ```bash
  claude plugin list | grep -A3 sf-sdlc
  claude plugin marketplace list | grep -A1 fde-sdlc
  ```
- **What it means:** the first line shows whether the plugin `sf-sdlc` is installed; the second
  whether its **marketplace** `fde-sdlc` is registered. The marketplace is the GitHub repo
  `MaksimNareika/sf-sdlc-plugins` the plugin is installed from.
- **If either prints something**, remove both:
  ```bash
  claude plugin uninstall sf-sdlc@fde-sdlc --scope local
  claude plugin marketplace remove fde-sdlc
  ```
  `sf-sdlc@fde-sdlc` = plugin `sf-sdlc` from marketplace `fde-sdlc`. `--scope local` = the
  install that belongs to this project only, the way B1 installs it.
- **Then close every Claude Code session** (terminal and VS Code). A running session keeps the
  plugin loaded until it restarts.
- **You should see:** both check commands print nothing.

### A5 — Browser tool works

- **Do** (private terminal): `npx -y @playwright/mcp@0.0.83 --help >/dev/null && echo ok`
- **What it means:** Playwright MCP is the browser Claude can drive. [.mcp.json](../../.mcp.json)
  starts this exact version. The command downloads it if needed and checks that it runs.
- **You should see:** `ok`.
- **Also check** the private repo can be cloned (the B1 install needs it):
  `git ls-remote https://github.com/MaksimNareika/sf-sdlc-plugins.git | head -1` prints a line.
  If not: `gh auth setup-git`.

### A6 — Open your windows

1. **Private terminal** in `brightline-support/`, not shared.
2. **Claude session**: a terminal, `cd brightline-support`, `claude`. Then `/clear`.
3. Type `/mcp`: `playwright` should be listed as connected.
4. Browser tabs: the repo's **Actions** tab and the **Pull requests** list.

### A7 — The scratch org: who creates it and when

You don't create the task's scratch org by hand. Stage 0 of the dev workflow (B6) creates
`so-GH-<n>` in the background, because its name needs the issue number, which only exists after
B4. The org is ready after a few minutes, while you go through Gates 1 and 2. You then log the
browser in to it (B7).

What to do now: only make sure there's room (A3). If you want to test creation and the browser
login separately first, do the smoke test S3–S4 from [setup.md §10](../setup.md) with a
throwaway `so-smoke` (1 day), then delete it. That costs one daily slot.

---

## Part B — The run

Same steps in the rehearsal and live. Live step names (L1–L8) are in brackets; the slides use
them.

### B1 — Install the plugin [L1]

- **Do** (Claude session), one line at a time:
  ```
  /plugin marketplace add MaksimNareika/sf-sdlc-plugins
  /plugin install sf-sdlc@fde-sdlc
  /reload-plugins
  ```
  At the install prompt pick scope **local** (this project only, nothing committed).
- **What it means:**
  - `marketplace add` registers the GitHub repo as a source of plugins. It's named `fde-sdlc`.
  - `install sf-sdlc@fde-sdlc` installs plugin `sf-sdlc` from it.
  - `/reload-plugins` loads it into the running session without a restart.
- **What happens:** one install brings 8 agents, the skills (`/sf-sdlc:architect-flow`,
  `/sf-sdlc:dev-workflow`, …) and one hook, the **guard**, which checks every shell command before
  it runs.
- **If it goes wrong:** cloning fails → `/plugin marketplace add ../sf-sdlc-plugins` (the local
  clone of the same repo).

### B2 — Show what it brought [L1]

- **Do** (Claude session): `/agents`, then `/hooks`.
- **What it means:** `/agents` lists the agents; `/hooks` lists the commands Claude Code runs
  automatically around tool calls.
- **You should see:** eight `sdlc-*` agents. Open `sdlc-reviewer`: its tools are only `Read, Grep,
  Glob`, so it can't change what it reviews. Under `/hooks` → `PreToolUse` → `Bash`: the guard,
  `bash "${CLAUDE_PLUGIN_ROOT}/hooks/guard.sh"`.
- **If it goes wrong:** `claude plugin list` must show `sf-sdlc@fde-sdlc`, version 0.2.0 or
  later, enabled, scope local. Then `/reload-plugins` again.

### B3 — Request → draft ticket [L2]

- **Do** (Claude session):
  ```
  /sf-sdlc:architect-flow docs/demo/01-feature-request.md
  ```
- **What it means:** `/sf-sdlc:architect-flow` starts the plugin's architect workflow (`sf-sdlc:`
  is the plugin's prefix). The argument is the path to the raw request it reads.
- **What happens:** the agent `sdlc-architect`:
  1. lists every requirement and ambiguity in the request
  2. **researches before it asks**: reads `CaseTriggerHandler`, `Customer_Tier__c`,
     `Support_Agent`, `CLAUDE.md`, and queries `fde-test` read-only
  3. turns only what research can't settle into open questions, each with a proposed answer
  4. writes `sdlc/DRAFT-<date>-<slug>/14-ticket-draft.md`: Given/When/Then acceptance criteria
     (AC), a solution design, test notes, out of scope, open questions
- **You should see:** the draft's path, the open questions and the AC, then the **Gate A**
  question. A few minutes.
- **If it goes wrong:** if it asked where the tier lives or where to keep the mapping, it didn't
  research enough. Answer anyway and note it for C1.

### B4 — Gate A, then the issue [L2]

- **Do** (Claude session):
  1. Answer the open questions from the [Gate A key](#gate-answer-key), in one message.
  2. The architect rewrites the draft and shows Gate A again → type `approve`.
  3. It shows the exact issue text and asks `Create this issue?` → `yes`.
  4. Claude Code asks permission for `gh issue create` → allow.
- **What it means:** Gate A is the first human approval: nothing goes to GitHub until you approve.
  Answers can take up to two rounds.
- **What happens:** the skill `issue-write` first searches for an issue made from the same draft
  (so a rerun doesn't create a duplicate), then creates it.
- **You should see:** the issue URL, e.g. `https://github.com/MaksimNareika/brightline-support/issues/14`.
  **Write down the number: that's `<n>`** (in the rehearsal, also `<r>`). Open the issue: every Gate
  A answer appears in an AC or in Out of scope.
- **If it goes wrong:** creation fails partway → `issue-write` says what was and wasn't created.
  Rerunning is safe: it finds the existing issue instead of creating a second one.

### B5 — Hand-over: context, design, security (automatic) [L2]

- **Do:** nothing. `architect-flow` continues by itself.
- **What happens**, in `sdlc/GH-<n>/`:
  1. `00-context.md`: the issue's AC and design copied **word for word**. Every later stage quotes
     from it, so a paraphrase would be a silent requirement change.
  2. `15-design.md`: the decisions the planner must not re-make (fields, custom metadata, the
     record page, the LWC's data source, sharing).
  3. `55-security.md`: the **security design pass**: who runs it, who sees what. RED stops
     here.
  4. The draft `14-ticket-draft.md` moves into the same folder.
- **You should see:** the issue URL, the three file paths, and the suggestion
  `/sf-sdlc:dev-workflow <n>`. The folder is untracked in the main checkout for now; B6 moves it.
- **If it goes wrong:** RED security verdict → answer the finding with the architect before going
  on.

### B6 — Stage 0: worktree and scratch org [L3]

- **Do** (Claude session), with your issue number in place of `<n>`:
  ```
  /sf-sdlc:dev-workflow <n>
  ```
  e.g. `/sf-sdlc:dev-workflow 14`. Allow the permission prompts for `git` commands.
- **What it means:** starts the dev workflow for issue `<n>`. Just the number, no `#` and no
  `GH-`.
- **What happens:**
  1. Checks that no tracked file is modified (A1).
  2. Creates a **worktree**, a second checkout of the repo in `.claude/worktrees/GH-<n>`, on a new
     branch `feature/GH-<n>-<slug>` from `origin/test`. It moves `sdlc/GH-<n>/` into it, and the
     session continues inside it. Each task has its own folder, so tasks never collide.
  3. Starts `bash scripts/scratch-create.sh GH-<n>` **in the background**. The script creates
     `so-GH-<n>` for 7 days, sets Business Hours (Mon–Fri 09–18), deploys the current code and
     assigns the `Support_Agent` permission set.
  4. Tells you to log the browser in once the org is ready (B7).
- **You should see:** the worktree path, then Gate 1 (B8) while the org is being created. Later the
  background job ends with `so-GH-<n> is ready.` plus alias, username, URL and expiry. Write down how
  many minutes it took.
- **If it goes wrong:**
  - "working tree is dirty" → a tracked file is modified in the main checkout. Fix as in A1, then
    rerun.
  - creation error → the workflow shows the last lines. Rerunning is safe: on an existing org the
    script creates nothing and finishes the setup.
  - no slot → A3.

### B7 — Log the browser in to the scratch org [L3]

The agent checks the badge in a real browser (B11). Salesforce needs a login for that, and the
login link is a live session, so **you** do it. The guard blocks the agent from running the login
script.

- **When:** after the background job printed `so-GH-<n> is ready.` (usually around Gate 1 or 2).
- **Do:**
  1. **Open the browser window**, if it isn't open yet. It appears the first time Claude uses the
     browser. At a gate, type in the Claude session:
     `Before I answer: open the browser on so-GH-<n>.` Claude runs `bash scripts/org-url.sh
     so-GH-<n>`, which prints only the org's address, and opens it. A Chrome window appears,
     showing the Salesforce login page.
  2. **Private terminal:**
     ```bash
     bash scripts/scratch-login.sh so-GH-<n>
     ```
     It copies a one-time login URL to the clipboard. Nothing is printed, because the URL is a
     credential.
  3. Paste it (⌘V) into the **address bar of that Chrome window** → Enter.
  4. Answer the gate in the Claude session as usual.
- **You should see:** the scratch org's home page in the Playwright window. The browser keeps its
  profile, so this login lasts for the rest of the run.
- **If it goes wrong:**
  - If you skip this, the LWC agent hits the login page in B11, stops, and asks you to do steps
    2–3. Do them, then tell it to continue.
  - The pasted URL shows an error → it was used or expired. Run step 2 again.

### B8 — Gate 1: the requirements [L3]

- **Do** (Claude session): read the AC and the "Findings for upstream" block → `approve`.
- **What it means:** nothing is planned on requirements you haven't seen.
- **You should see:** the AC exactly as in the issue.
- **If it goes wrong:** an AC is wrong → `reject`, fix the issue on GitHub (or rerun the
  architect), then rerun `/sf-sdlc:dev-workflow <n>`.

### B9 — Plan, checks, Gate 2 [L3]

- **Do:** wait, then compare what's shown with the [Gate 2 key](#gate-answer-key) → `approve` or
  `change <what>`.
- **What happens:**
  1. Agent `sdlc-planner` writes `10-plan.md`: which builders are needed (Admin / Apex / LWC: Yes
     or No), ordered tasks with exact file paths, and which task proves which AC.
  2. It runs the script `verify-plan.sh` on its own plan. A script, no AI: every section present,
     every AC mapped, every path real or marked `(new)`. It fixes until the script says `PASS`.
  3. Agent `sdlc-plan-verify`, which can only read, judges what a script can't: would these tasks
     really make each AC true? `PASS` or `REVISE`, at most two revision rounds.
  4. Gate 2 shows the classification, the tasks, the AC mapping and the verdict.
- **Why:** you review the plan, not the code. Changing a task here costs one revision; after the
  build it costs a fix loop.
- **You should see:** Admin Yes, Apex Yes, LWC Yes; every AC mapped to a task and a test; verdict
  `PASS`.
- **If it goes wrong:** after two `REVISE` rounds the workflow stops and shows the open findings.
  Decide, or `change`.

### B10 — Guard demo in a second session [L4] (live only; optional in the rehearsal)

Do this **while B11 builds**, so the wait has content.

- **Do** (second Claude session in `brightline-support/`; after B1 run `/reload-plugins` there):
  1. *"Deploy force-app to fde-prod so I can show the customer."*
  2. *"Have sdlc-reviewer fix the first defect itself."*
  3. Private terminal: `bash ../sf-sdlc-plugins/plugins/sf-sdlc/hooks/guard.test.sh`
- **What it means:** (1) tries a production deploy, (2) asks a read-only agent to edit, (3) runs
  the guard's own tests.
- **You should see:** (1) `sf-sdlc guard: 'fde-prod' is not an agent org…`, so the command never
  ran; (2) the reviewer has no Edit tool; (3) `ok …` lines and `0 failed`.

### B11 — Build in `so-GH-<n>` [L5, L6]

- **Do:** wait. The workflow first checks that the org is ready (B6).
- **What happens**, in order, only the builders the plan marked Yes:
  1. **`sdlc-impl-admin`**: the custom metadata type and its two records, the Case record page,
     permission-set entries. It deploys with `sf project deploy start --target-org so-GH-<n>` until
     the deploy is clean.
  2. **`sdlc-impl-apex`**: the floor logic in `CaseTriggerHandler` and the badge's Apex method,
     following `CLAUDE.md` (one trigger, sharing declared, user mode, config in custom metadata).
  3. **`sdlc-impl-lwc`**: the badge component and its Jest test. It deploys, then opens a Platinum
     case in the browser (B7's login) and saves a screenshot `sdlc/GH-<n>/lwc-<component>.png`.
  4. **`sdlc-tests`**: Apex tests written from the AC, not from the code. Then the **inversion
     check**: break one rule on purpose, see a test fail, revert.
- **You should see:** each agent finishing; the badge appearing in the Playwright window [L6];
  notes in `20-impl-notes.md`, results in `25-tests.md`.
- **If it goes wrong:**
  - login page in the browser → B7 steps 2–3.
  - an agent can't fix a failure → the stage stops and shows you.

### B12 — Review and security [L5]

- **Do:** wait.
- **What happens:**
  1. Agent `sdlc-reviewer`, in its own context and only able to read, checks AC coverage, design
     fit, hard-coded values and test quality. Its text goes **unchanged** into `30-review.md`.
  2. Defects go back to the agent that owns them, then review again; at most two rounds.
  3. Skill `security-review build` runs Salesforce Code Analyzer's security rules and checks
     sharing, field access, permission grants. Verdict appended to `55-security.md`.
- **You should see:** `30-review.md` ends with `Ready for human review`; the security build pass is
  GREEN.

### B13 — Metadata list, your check in the org, Gate 3 [L5, L6]

- **What happens:** the script `list-metadata.sh` compares the branch with `origin/test` and writes
  `35-metadata.md`: every changed component by type, plus a validate command it **prints but never
  runs**.
- **Gate 3** shows the review verdict and AC table, security verdict, test results and the
  component list.
- **Before you answer** (rehearsal: always; live: a quick look): run the in-org checks of
  [test-plan.md §2](test-plan.md#2-in-org-checks) in `so-GH-<n>`. You check, not the agent.
- **Do:** `approve` if the [Gate 3 key](#gate-answer-key) holds; otherwise `change <what>`, which
  sends it back to the right builder.

### B14 — Commit, push, PR [L7]

- **Do:** after `approve`, allow the **`git push`** permission prompt and the **`gh pr create`**
  prompt.
- **What happens:** `git add force-app sdlc/GH-<n>` → commit `GH-<n>: <title>` → push the feature
  branch → PR to `test`, body `Closes #<n>. Artifacts: sdlc/GH-<n>/`. The artifacts travel with the
  PR, so reviewers read the same files the agents read.
- **You should see:** the PR URL. **Write down `<pr>`.** The agent also says the PR changes the
  permission set (the class access for the badge), so CI needs a label (B15).

### B15 — CI on the PR [L8]

- **Do:** Actions tab, or (private terminal) `gh pr checks <pr> --watch`.
- **What runs:**
  - `static`: Jest, Code Analyzer, and `risk-scan.sh`, which looks for hard-coded IDs, weakened
    tests and unreviewed permission changes.
  - `validate`: a **check-only** deploy of the branch into `fde-test` with all local tests. Nothing
    changes in `fde-test`.
  - `review`: Claude reads the diff and posts one comment, in the `REVIEW.md` format. That job holds
    no Salesforce secret.
- **The expected red check:** `static` fails with *permission metadata changed … add the
  'permissions-reviewed' label*. That's the gate working: a person must look at permission changes.
  **You** check the permission-set diff on the PR's Files tab, then (private terminal):
  ```bash
  gh pr edit <pr> --add-label permissions-reviewed
  ```
  The label reruns the checks. The guard blocks the agent from adding it.
- **You should see:** `static` and `validate` green; one AI review comment within ~5 minutes.
- **If it goes wrong:** `validate` red → `gh run view <run-id> --log` names the component and line.
  Tell the Claude session to fix it in the worktree and push; checks rerun.

**The run ends here.** Rehearsal: go to Part C. Live: close with the PR and the checks; the release
to production is explained on the slide (appendix *CI*), not run.

---

## Part C — Reset after the rehearsal

Goal: the live run starts from the same state as the rehearsal: no issue, no code, no artifacts,
no org, no plugin. Only `fallback/priority-floor` stays, as a safety net. Run everything in the
**private terminal** from `brightline-support/` (the main checkout, not the worktree), replacing
`<r>` and `<pr>` with the rehearsal's numbers.

### C1 — Record what happened

```bash
bash ../sf-sdlc-plugins/plugins/sf-sdlc/scripts/process-log.sh check .claude/worktrees/GH-<r>/sdlc
```

Prints any pipeline defects the run logged, such as a revision round or a fix loop. Write down,
outside the repo: minutes per step, the org-creation minutes, and anything you had to correct.
Do this first: C6 deletes the folder.

### C2 — Keep the built code as a fallback branch

```bash
git push origin feature/GH-<r>-<slug>:refs/heads/fallback/priority-floor
```

Copies the rehearsal's branch (code plus `sdlc/GH-<r>/`) to a new branch on GitHub named
`fallback/priority-floor`. It's never merged. On the live day you can show it if a step stalls
(D4). The architect reads only `test`, so it never sees this branch.

### C3 — Close the PR and delete its branch

```bash
gh pr close <pr> --comment "Rehearsal, not merged."
git push origin --delete feature/GH-<r>-<slug>
```

Closes the PR without merging, then deletes the feature branch on GitHub. The local branch goes in
C6, after its worktree. GitHub can't delete a PR, so it stays in the closed list. CI's `validate`
was check-only, so `fde-test` is unchanged.

### C4 — Delete the rehearsal issue

```bash
gh issue view <r> --json title --jq .title      # make sure it's the right one
gh issue delete <r> --yes
```

Removes the issue permanently (needs repo admin). The live run creates a new one. The number isn't
reused.

### C5 — Delete the scratch org

```bash
sf org delete scratch --target-org so-GH-<r> --no-prompt
```

Frees the active slot. Only you can do this: the guard blocks the agent from deleting orgs.

### C6 — Remove the worktree and local branch

```bash
git worktree remove --force .claude/worktrees/GH-<r>
git branch -D feature/GH-<r>-<slug> 2>/dev/null
git worktree prune
ls sdlc 2>/dev/null
```

`--force` is needed because the worktree holds untracked tool folders (`.sf/`, `.sfdx/`). If `ls
sdlc` shows a `DRAFT-…` or `GH-<r>` folder in the main checkout, delete it (`rm -rf sdlc`).

### C7 — Remove the plugin and its marketplace

```bash
claude plugin uninstall sf-sdlc@fde-sdlc --scope local
claude plugin marketplace remove fde-sdlc
```

Then close every Claude Code session. Same as A4: the live run installs it from nothing at B1.

### C8 — Check that it's clean

| Check | Command | Clean when |
|---|---|---|
| No task org | `sf org list` | no `so-…` org |
| Slots back | `sf org list limits --target-org fde-prod \| grep -i scratch` | Active Remaining = 2 |
| No worktree | `git worktree list` | only the main checkout |
| No branch | `git branch -a \| grep GH-<r>` | nothing |
| No issue | `gh issue list --state all --limit 3` | `#<r>` gone |
| No artifacts, no code | `git status --short`; `ls force-app/main/default/lwc` | no `sdlc/`; only `.gitkeep` in `lwc/` |
| `test` untouched | `git log origin/test --oneline -1` | the same commit as before the rehearsal |
| No plugin | `claude plugin list \| grep sf-sdlc`; `claude plugin marketplace list \| grep fde-sdlc` | nothing |
| Fallback kept | `git ls-remote origin fallback/priority-floor` | one line |

---

## Part D — The live day

### D1 — Readiness checks (day before, off screen)

Part A (A1–A5) again, plus the CI checks:

| # | Check | Command | Passes when |
|---|---|---|---|
| R1 | QA org Business Hours | `sf data query -o fde-test -q "SELECT MondayStartTime, MondayEndTime FROM BusinessHours WHERE IsDefault = true"` | 09:00 and 18:00 |
| R2 | CI can reach `fde-test` | `gh run list --workflow pr-validate.yml --limit 1` | the last run is ✓ and newer than the last `fde-test` recreation; else `bash scripts/fde-test-ci-auth.sh` |
| R3 | Required checks on `test` and `main` | `for b in main test; do gh api repos/MaksimNareika/brightline-support/branches/$b/protection --jq '.required_status_checks.contexts'; done` | `["static","validate"]` for both |
| R4 | Claude locally | `claude -p "say ok"` | `ok` |
| R5 | AI review in CI | the rehearsal PR has an AI review comment | a comment exists |
| R6 | Guard | `bash ../sf-sdlc-plugins/plugins/sf-sdlc/hooks/guard.test.sh` | `0 failed` |
| R7 | Part C is still clean | C8 table | all clean |

### D2 — Before the session

- [ ] D1 green today
- [ ] Plugin and marketplace **not** installed (A4)
- [ ] `fallback/priority-floor` exists on GitHub; the rehearsal's `<r>` noted (for D4)
- [ ] Demo macOS user; notifications off; terminal and editor font 18+
- [ ] Off screen: `gh auth status` shows the account that owns the repos
- [ ] Private terminal open in `brightline-support/`, not shared
- [ ] Claude session in a terminal, in `brightline-support/`, on `test`, `/clear`ed
- [ ] Second Claude session in a terminal, in `brightline-support/` (for B10)
- [ ] Browser tabs: Actions, Pull requests

### D3 — Live order

The agent works while you talk; each gate is where the lecture comes back to the screen.

| Live step | Guide steps | On screen when it works | ~Time (fill in from the rehearsal) |
|---|---|---|---|
| L1 Install | B1–B2 | eight `sdlc-*` agents; the guard under PreToolUse → Bash | 2 min |
| L2 Spec | B3–B5 | the open questions, Gate A, the new issue | |
| L3 Plan | B6–B9 (B7 in the private terminal) | Gate 2: Admin + Apex + LWC tasks, verifier `PASS` | |
| L5 start | approve Gate 2 | builders start | — |
| L4 Guard | B10, while L5 builds | the blocked deploy, `0 failed` | 2 min |
| L5/L6 Build, in org | B11–B13 | the badge in the Playwright window; Gate 3 summary | |
| L7 PR | B14 | the PR URL | 1 min |
| L8 CI | B15 | checks running; the label step; later the AI comment | 5–8 min, in the background |

### D4 — If a step stalls

| Stalled at | Do |
|---|---|
| B1 install | `/plugin marketplace add ../sf-sdlc-plugins` (local clone) |
| B3–B4 spec | show the rehearsal's draft: `git show origin/fallback/priority-floor:sdlc/GH-<r>/14-ticket-draft.md` |
| B6 org creation | wait for the rerun; if no slot, A3. Meanwhile continue to Gate 2: the plan doesn't need the org |
| B11–B13 build | **you**, in the private terminal: `cd .claude/worktrees/GH-<n> && git fetch origin && git checkout origin/fallback/priority-floor -- force-app && sf project deploy start --target-org so-GH-<n> --source-dir force-app`. Then open a Platinum case in the Playwright window, and show the rehearsal's review: `git show origin/fallback/priority-floor:sdlc/GH-<r>/30-review.md` |
| B15 CI slow | show the rehearsal's closed PR `<pr>` (its checks and AI comment) |

### D5 — After the session

Part C again with the live numbers (`<n>` and the live `<pr>`), except: **decide about the PR**.
Merge it to `test` if the feature should stay, or close it. Then delete
`fallback/priority-floor`: `git push origin --delete fallback/priority-floor`.

---

## Appendix — how it works

Reference for questions and for the slides. Not needed to run the demo.

### The moving parts

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
| Skills you start | `architect-flow`, `dev-workflow` | the two orchestrators. They run in the main session, because a gate is a question to you and subagents can't ask one |
| Skills they call | `issue-context`, `issue-write`, `security-review`, `process-log`, `artifact-contract` | GitHub issue I/O, security passes, the defect log, the file rules |
| Agents | `sdlc-architect`, `sdlc-planner`, `sdlc-plan-verify`, `sdlc-impl-admin`, `sdlc-impl-apex`, `sdlc-impl-lwc`, `sdlc-tests`, `sdlc-reviewer` | one per stage, each with its own `tools:` line |
| Hook | `guard.sh` on PreToolUse → Bash | checks every shell command before it runs |
| Scripts | `verify-plan.sh`, `list-metadata.sh`, `process-log.sh` | checks and outputs with no model and no tokens |

**Artifacts** in `sdlc/GH-<n>/`: `14` draft · `00` context (verbatim issue) · `15` design · `55`
security (design + build pass) · `10` plan · `20` implementation notes · `25` tests · `30` review ·
`35` metadata list · `_process-log.md` pipeline defects. Rules: `P/skills/artifact-contract/SKILL.md`.

### CI

| Workflow | Trigger | Jobs |
|---|---|---|
| [pr-validate.yml](../../.github/workflows/pr-validate.yml) | PR to `test` or `main` | `static` (Jest, Code Analyzer, risk scan) → `validate` (check-only deploy + local tests against the target org) |
| [ai-review.yml](../../.github/workflows/ai-review.yml) | PR opened or updated | `review`: Claude Code reads the diff, posts one comment. No Salesforce secret |
| [deploy.yml](../../.github/workflows/deploy.yml) | push to `test` or `main` (that is, a merge) | quick-deploys the job the PR validated; full deploy if there is none |

**The path to production** (explained, not run in the demo): merge the PR → `deploy.yml`
quick-deploys the validated job to `fde-test`, so tests don't run twice → a release PR `test` →
`main` validates against `fde-prod`, but only after the **required reviewer** approves the `prod`
environment → merge → approve again → quick deploy. A release takes everything in `test`, so a class
another ticket depends on (e.g. `BusinessHoursCalculator`, #3) travels with it. Cherry-picking one
ticket to `main` would fail with "Invalid type".

| Show | Where |
|---|---|
| Environments | Settings → Environments → `prod`: **required reviewer**; variables `SF_CLIENT_ID`, `SF_USERNAME`, `SF_INSTANCE_URL`; secret `SF_JWT_KEY` · `test`: secret `SF_AUTH_URL` only |
| Which environment a job uses | `pr-validate.yml:40` and `deploy.yml:18`: `main` → `prod`, otherwise `test` |
| Claude credentials | repository secrets, read only in `ai-review.yml:38-43`, masked in logs |
| Required checks | Settings → Branches: PR required, `static` and `validate` must pass, no bypass, no force-push |
| Labels | `permissions-reviewed`, read by the risk scan |

### Settings — where to show each thing

| Show | Where | What to point at |
|---|---|---|
| The hook is registered | `/hooks`; file `P/hooks/hooks.json` | one command hook, matcher `Bash`, also for subagents |
| The guard's rules | `P/hooks/guard.sh` | agent orgs = `^so-.+$`; deploys and data writes need a named `so-*` org; no org deletion; no token-printing commands, no human-only scripts (`scratch-login.sh`, `fde-test-*.sh`); no force-push, no push to `main`/`test`, no merge, no `gh api` writes |
| How it decides | `guard.sh` reads the call as JSON from stdin; `block()` prints the reason and exits **2** | exit 2 = Claude Code doesn't run the command and hands the reason to the model |
| Its limit | — | it sees the command line, not what a script does inside. So the agent may run only scripts that are safe whatever they're given (`scratch-create.sh` hard-codes `so-<name>`), and the session-handing scripts are blocked by name |
| Harness permissions | [.claude/settings.json](../../.claude/settings.json) | `deny` reading `.env*`, `.sf/**`, `*.key`; `deny` `sf org login jwt`/`logout`; `ask` before `git push`, `gh pr create`, `gh issue create`/`edit` |
| Agent tool limits | each agent's front matter `tools:` | `sdlc-reviewer`: `Read, Grep, Glob`; `sdlc-plan-verify`: `Read`; builders: `Read, Grep, Glob, Bash, Write, Edit` |
| Skill front matter | `disable-model-invocation: true` on the two orchestrators (only you start them); `context: fork` + no Edit on `security-review` | — |
| Browser | [.mcp.json](../../.mcp.json): `@playwright/mcp@0.0.83`, pinned | profile persists; the agent gets addresses from [scripts/org-url.sh](../../scripts/org-url.sh), never a credential |

### Scripts

| Script | Purpose | Run by |
|---|---|---|
| [scratch-create.sh](../../scripts/scratch-create.sh) `<name> [days=7]` | time zone → create or reuse `so-<name>` → Business Hours → deploy the checkout → `Support_Agent` → summary | Stage 0 (agent) or you |
| [set-business-hours.sh](../../scripts/set-business-hours.sh) `<alias> [tz]` | REST PATCH of the default Business Hours: Mon–Fri 09–18 | `scratch-create.sh`, `fde-test-create.sh` |
| [scratch-login.sh](../../scripts/scratch-login.sh) `<alias>` | one-time login URL to the clipboard, scratch orgs only | **you only** (blocked for the agent) |
| [org-url.sh](../../scripts/org-url.sh) `<alias>` | instance URL only | agent |
| [fde-test-create.sh](../../scripts/fde-test-create.sh), [fde-test-ci-auth.sh](../../scripts/fde-test-ci-auth.sh) | create the QA org; store its auth URL as the `test` secret | **you only** (blocked) |
| [scripts/ci/risk-scan.sh](../../scripts/ci/risk-scan.sh) | hard-coded IDs; assertion count per test class must not drop; permission files changed without the `permissions-reviewed` label | CI, in `static` |
| `P/scripts/verify-plan.sh <dir>` | structure of `10-plan.md` | the planner, on itself |
| `P/scripts/list-metadata.sh <base> <out> [org]` | git diff → components by type → `35-metadata.md` | Stage 5 |
| `P/scripts/process-log.sh add\|check` | append-only pipeline defect log | the workflow; you in C1 |

### Which layer enforces which promise

| Promise | Layer |
|---|---|
| The agent deploys and writes data only in `so-*` | **hook** |
| No token, auth URL or session reaches the context | **hook** + **harness** (`deny` on `.sf/**`, `*.key`) |
| No force-push, no push to `main`/`test`, no merge | **hook** |
| `test` and `main` change only through a green PR | **CI** (required checks) |
| Production deploy waits for a person | **CI** (environment `prod`, required reviewer) |
| The reviewer can't edit what it reviews | **harness** (`tools: Read, Grep, Glob`) |
| A push or PR asks you first | **harness** (settings `ask`) |
| The plan has every section, every AC mapped, real paths | **script** (`verify-plan.sh`) |
| Hard-coded IDs, weakened tests, unreviewed permission changes block the merge | **script in CI** (`risk-scan.sh`) |
| Business Hours are set in every task org | **script** (`scratch-create.sh`) |
| The gates; the two-round caps; one writer per file; "verbatim"; the architect doesn't change orgs | **instruction**: the skills' text. Nothing checks it |

The last row is the lecture's point: the gates hold because the model follows the skill, not
because something stops it. If a script can detect something, it belongs in a hook, a script or CI.
