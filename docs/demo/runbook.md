# Demo runbook

How to prepare, run and reset the demo. Environment first: `docs/setup.md` including its smoke
test. What "correct" means for the feature itself: `docs/demo/test-plan.md`. Steps marked **[§8]**
depend on changes that are planned but not built yet.

- **Base feature, built before the lecture:** GH-2 *First-response SLA* from
  `docs/demo/01-meeting-notes.md`.
- **Live task:** the change request in `docs/demo/02-change-request.md` (Gold 75%, amber badge
  under 30 minutes). It is called **GH-3** below; the real issue number is whatever GitHub hands out,
  because issues and PRs share one counter and a number is never reused. Write the real numbers in
  the prep file after each phase.
- **GH-2 and GH-3 are names, not issue numbers.** The business hours helper is the real issue
  **#3**; it has nothing to do with the name GH-3.

`fde-test` is a scratch org that lives at most 30 days. Before phase A, check its expiry in
`sf org list`: if it is before the lecture day, recreate it (setup §8, *Recreating `fde-test`*)
**before** A, so the org that A–F prepare is the one used live.

## Phases

| Phase | When | What | Output |
|---|---|---|---|
| A | L-14 | Dry run GH-2, end to end | GH-2 merged to `test`, deployed to `fde-test`; timings |
| B | L-14 | Test GH-2 (test plan §2) in its scratch org, then in `fde-test` | all GH-2 cases pass |
| C | L-12 | Recording T: deploy-failure triage on a PR with an invented field | video: red `validate`, triage comment |
| D | L-4 | Rehearsal GH-3 with a stopwatch | fallback branches; GH-3 in `fde-test` |
| E | L-4 | Recording R1: the change request to production | video of merge → `test` → promotion → `prod` |
| F | L-3 | Reset for the live run | org and branches back to the GH-2 state |
| G | L-1 / L | Before the session | checklist |
| H | L | Live segment | — |

## Gate answer key

Answer the gates the same way every run, so the spec, the test plan and the fallback branches agree.

**GH-2, Gate A** (architect's questions):

| Question | Answer |
|---|---|
| Targets | High 2 h, Medium 8 h, Low 24 h — **business** hours (Low is about 2.7 working days; confirm it, it is the point of the question) |
| Which hours | Default Business Hours, Mon–Fri 09:00–18:00, for **every** tier |
| Platinum | half the time, on business hours. 24/7 for Platinum → **Out of scope** |
| Gold | parked: same as Standard (1.0) |
| "Replied" | Status moves off `New`. Email-based → Out of scope |
| Late | owner → `Escalations` queue, breach flag set; not if the status is no longer `New` |
| Integration user | anyone with a custom permission (e.g. `SLA_Bypass`), assigned by permission set — config, not usernames in code |
| Helper (#3) | reuse `BusinessHoursCalculator` |
| Badge | countdown on the case page, red when overdue |
| Dashboard | Out of scope |

**GH-2, Gate 2** (steer if the plan differs):

- tier multipliers and priority targets in **custom metadata**, not Apex constants (keeps GH-3 small)
- the respond-by time is set on insert and when priority or tier changes; an admin may edit it (the
  test plan relies on that)
- escalation runs as a scheduled job that can also be started on demand (keeps the in-org test
  deterministic). If the room picks a Flow in §4–6, say why the demo still goes with the job

**GH-3, Gate A:** Gold multiplier 0.75; amber when less than 30 minutes remain, red when overdue;
the change edits GH-2's confirmed AC — the architect comments on GH-2 and GH-3 links to it.
**GH-3, Gate 2:** a custom metadata change plus the LWC; no new Apex expected. More than that is a
plan finding.

---

## Phase A — dry run GH-2

Claude Code in `brightline-support/`, on `test`, plugin installed, `/clear`ed.

| # | Do | Check |
|---|---|---|
| A1 | `/sf-sdlc:architect-flow docs/demo/01-meeting-notes.md` | the draft lists open questions with defaults; it found `BusinessHoursCalculator`, `Customer_Tier__c` and the `Escalations` queue on its own. If it asked about any of those, log a `process-log` row |
| A2 | Gate A: answer from the key; `approve` | AC are Given/When/Then; each answer from the key appears in an AC or in Out of scope |
| A3 | confirm the issue text | issue GH-2 has `Business need`, `Acceptance Criteria`, `Solution Design`, `Test Notes`, `Out of scope`; `sdlc/GH-2/` has `00`, `14`, `15`, `55` (design pass, not RED) |
| A4 | `/sf-sdlc:dev-workflow 2` → Stage 0 | `git worktree list` shows the task worktree; `sf org list` shows `so-GH-2` (note the minutes it took) |
| A5 | off screen: `bash scripts/scratch-login.sh so-GH-2`, paste the URL into the Playwright window | the window shows the scratch org's home page |
| A6 | Gate 1: `approve` | `00-context.md` AC match the issue word for word |
| A7 | Gate 2: steer from the key | Work Classification matches the design; every AC maps to a task and a test; verifier `PASS`; multipliers in custom metadata |
| A8 | wait for the build | `20-impl-notes.md` has one section per agent that ran; `sdlc/GH-2/lwc-*.png` exists; `25-tests.md` all pass, with the inversion table; `30-review.md` has a verdict; `55-security.md` has a build pass; `35-metadata.md` lists the components |
| A9 | Phase B §2 in `so-GH-2` **before** Gate 3 | every GH-2 case passes. A failure goes back as `change` at Gate 3, not as a hand fix |
| A10 | Gate 3: `approve` | commit, push, PR to `test` opened by the agent |
| A11 | Actions tab | `static`, `org-drift`, `validate` green; one AI review comment in the `REVIEW.md` format |
| A12 | **you** merge the PR | `Deploy` ran the quick deploy to `fde-test` |
| A13 | Phase B §2 smoke subset in `fde-test` | passes |
| A14 | note timings per stage, `/usage`, `process-log check`; **you** delete `so-GH-2`, remove the worktree | prep file updated |

Keep the feature branch: phase C uses it.

## Phase B — test GH-2

Follow `docs/demo/test-plan.md` §2 in `so-GH-2` (A9), then the smoke subset in `fde-test` (A13).
After the dry run, fill the field names into `scripts/demo/check-sla.apex` (test plan §1) and
commit them to `test`, so the rehearsal and the live run use the same check.

## Phase C — recording T: deploy-failure triage [§8]

Shown in the AI-in-the-pipeline section. Any time after demo build step B9 works.

1. Branch from `test`; in `CaseTriggerHandler.cls` read a field that does not exist, e.g.
   `c.Respond_Deadline__c` — the "invented field" an agent produces.
2. Push, open a PR to `test`.
3. Expect `static` green, `validate` red (`No such column 'Respond_Deadline__c'`), then the triage
   comment naming the field, the file and the line, with a suggested fix.
4. Record steps 2–3 (cut the waiting), then **close the PR without merging** and delete the branch.

**Check:** the recording shows the red check and the triage comment; nothing reached `fde-test`.

## Phase D — rehearsal GH-3

Run phase H exactly as on the day, with a stopwatch. After each step, push a fallback branch:

| After | Fallback branch | Contains |
|---|---|---|
| Gate A | — | the GH-3 issue (keep it) |
| Gate 2 | `fallback/GH-3-plan` | `sdlc/GH-3/00`, `10` |
| Build + review | `fallback/GH-3-build` | the code, `20`–`35`, `55`, screenshot |
| PR | `fallback/GH-3-pr` | the PR, kept open as draft, with CI green and the AI comment |

Then run test plan §3 in `so-GH-3`, merge the PR to `test` (you), and run the §3 smoke subset in
`fde-test`.

## Phase E — recording R1: the change request to production

This is the "whole pipeline" of the practice exercise. Record it end to end; cut the waiting.

1. **You**: `gh pr create --base main --head test --title "Release 1: #3, GH-2, GH-3"`. A release
   promotes everything in `test` together, so a helper class (#3) always travels with the change
   that uses it.
2. `static`, `org-drift`, `validate` against `fde-prod` green; AI review comment.
3. Merge. The `Deploy` job waits on the `prod` environment → approve it as required reviewer.
4. Quick deploy to `fde-prod` succeeds; release notes appear **[§8]**.
5. In `fde-prod`: create a Gold, Medium case → respond-by is 6 business hours (test plan T3-02).

**Check:** the recording shows each of steps 1–5. From now on `fde-prod` holds the helper (#3), GH-2 and GH-3.

## Phase F — reset for the live run

The live run needs `test` and `fde-test` back at GH-2, and a free scratch-org slot.

| # | Do (you) | Check |
|---|---|---|
| F1 | delete `so-GH-3`; `git worktree remove` the GH-3 worktree; delete `feature/GH-3-*` locally and on GitHub | `sf org list` shows no `so-*`; `git worktree list` shows only the main checkout |
| F2 | revert GH-3 on `test`: branch from `test`, `git revert -m 1 <GH-3 merge commit>`, PR to `test`, merge | CI deploys to `fde-test`; a Gold Medium case there gets 8 h again (test plan T2-05) |
| F3 | remove the components GH-3 **added** (from `sdlc/GH-3/35-metadata.md`, if any) from `fde-test` with a destructive deploy — or, simpler, recreate `fde-test` from the reverted `test` (setup §8; one daily slot, a new expiry date, update the `test` environment) | the org-drift check, run locally against `fde-test` with base `origin/test`, is clean **[§8]** — otherwise it fails live |
| F4 | `fde-prod` is **not** reset: it keeps Release 1. The live PR goes to `test` only | — |
| F5 | uninstall the plugin: `/plugin uninstall sf-sdlc@fde-sdlc` | `/plugins` does not list it |
| F6 | `sf org list limits --target-org fde-prod \| grep -i scratch` | at least 2 active (with `fde-test` already counted) and 2 daily left for the lecture day (the live org + one spare) |

Without F3, the live PR fails the drift check, because `fde-test` would still hold GH-3's
components while `test` no longer does. That failure would make a good lecture point, but not by
accident.

## Phase G — before the session

- [ ] Demo macOS user; notifications off; terminal and editor font 18+
- [ ] Off screen: `gh auth status` → EPAM account; `claude -p "say ok"` works
- [ ] `sf org list` → only `fde-prod`, `fde-test` (expiry after today); no `so-*` left over
- [ ] Scratch quota checked today (F6)
- [ ] Plugin **not** installed
- [ ] `fde-test` holds GH-2, not GH-3: a Gold Medium case gets 8 h
- [ ] Fallback branches pushed; the issue numbers written in the prep file
- [ ] Recordings on the desktop: T (triage), R1 (release to production)
- [ ] A second terminal, **not** shared, in `brightline-support/` for `scratch-login.sh`
- [ ] Claude Code session started in `brightline-support/`, on `test`, `/clear`ed
- [ ] A **second** Claude Code session in `brightline-support/` for L4 (opened after L1, so the plugin is loaded: `/reload-plugins`)

## Phase H — live segment

Each gate is where the lecture comes back to the screen; the agent works while you talk. Order on
the day (deck outline in the prep file §3): L1, L2, L3, L5 start (approve Gate 2), L4 in the second
session, L5 end + L6 (Gate 3), L7, T, L8 with R1.

| Step | Do | On screen when it works | ~Time | If it stalls |
|---|---|---|---|---|
| L1 Install | `/plugin marketplace add <epam-org>/sf-sdlc-plugins` → `/plugin install sf-sdlc@fde-sdlc` → `/reload-plugins` → `/agents` | the `sdlc-*` agents listed | 2 min | `/plugin marketplace add ../sf-sdlc-plugins` |
| L2 Spec | `/sf-sdlc:architect-flow docs/demo/02-change-request.md` → Gate A (key) → issue | the new issue, linked to GH-2; a comment on GH-2 naming the changed AC | 6 min | show the rehearsal's GH-3 issue |
| L3 Plan | `/sf-sdlc:dev-workflow <n>` → Stage 0 starts the worktree and `so-GH-<n>` in the background → Gate 1 → plan + verify → Gate 2 | Gate 2: custom metadata + LWC tasks, verifier `PASS`. Meanwhile, in the private terminal: `bash scripts/scratch-login.sh so-GH-<n>`, paste the URL into the Playwright window | 6 min | `git switch fallback/GH-3-plan` in the worktree, rerun the workflow: it finds `00` and `10` and resumes |
| L4 Guard | runs **while L5 builds**, in the **second Claude session**: ask *"deploy force-app to fde-prod"*; then *"have sdlc-reviewer fix the first defect itself"*; then in a terminal `bash ../sf-sdlc-plugins/plugins/sf-sdlc/hooks/guard.test.sh` | `sf-sdlc guard: 'fde-prod' is not an agent org…`; the reviewer has no Edit tool; the test prints exit codes 2/0 | 2 min | always works |
| L5 Build | approve Gate 2 → agents compile (LSP), deploy to `so-GH-<n>` → tests → review → security → Gate 3 | Gate 3 summary: review verdict, tests, security, component list | 8 min | `git switch fallback/GH-3-build`, then **you**: `sf project deploy start --source-dir force-app --target-org so-GH-<n>` (~2 min) |
| L6 In org | the LWC agent's browser check on a Gold case | amber badge, screenshot saved | 2 min | open the case by hand in the Playwright window |
| L7 PR | approve Gate 3 → commit, push, `gh pr create --base test` | the PR URL | 1 min | `fallback/GH-3-pr` |
| L8 CI | Actions tab: `static`, `org-drift`, `validate`; come back later for the AI comment | green checks; the comment | 5–8 min, in the background | the rehearsal PR |
| T | play recording T with the AI-in-the-pipeline slide (§12) | — | 1 min | — |
| R1 | play recording R1 (phase E) | — | 3 min | — |

Total live on screen: about 30 minutes, spread over six lecture sections.

After the lecture: **you** delete `so-GH-<n>`, close or merge the live PR, update the prep file.
