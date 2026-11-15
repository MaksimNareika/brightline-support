# Demo runbook — the live session

What to do on screen, in order, and what to do when a step stalls. Before the day:
[preparation.md](preparation.md) (phases A–G and the readiness checks). How each step works
underneath: [walkthrough.md](walkthrough.md). Expected values: [test-plan.md](test-plan.md).

**GH-3** below is the live change request ([02-change-request.md](02-change-request.md)); `<n>` is
the issue number GitHub hands out live. **GH-2** is the base feature, built before the session.
Both are names, not issue numbers; the business hours helper is the real issue **#3**.

## Start state

Phase G of [preparation.md](preparation.md) is ticked: plugin and marketplace **not** installed,
`fde-test` holds GH-2, fallback branches pushed, one terminal Claude Code session in
`brightline-support/` on `test`, a private terminal for `scratch-login.sh`, recording R1 ready.

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
  deterministic). If the room picks a Flow at the "Flow or Apex?" slide, say why the demo still
  goes with the job

**GH-3, Gate A:** Gold multiplier 0.75; amber when less than 30 minutes remain, red when overdue;
the change edits GH-2's confirmed AC — the architect comments on GH-2 and GH-3 links to it.
**GH-3, Gate 2:** a custom metadata change plus the LWC; no new Apex expected. More than that is a
plan finding.

## Live steps

The agent works while you talk; each gate is where the lecture comes back to the screen. Order on
the day: L1, L2, L3, L5 start (approve Gate 2), L4 in the second session, L5 end + L6 (Gate 3), L7,
L8, R1. The slide for each step is named in [the lecture plan](../lecture/lecture-plan.md).

| Step | Do | On screen when it works | ~Time | If it stalls |
|---|---|---|---|---|
| L1 Install | in the terminal session: `/plugin marketplace add MaksimNareika/sf-sdlc-plugins` → `/plugin install sf-sdlc@fde-sdlc` (scope: local) → `/reload-plugins` → `/agents` → `/hooks` | eight `sdlc-*` agents; the guard under PreToolUse → Bash | 2 min | `/plugin marketplace add ../sf-sdlc-plugins` (the local clone) |
| L2 Spec | `/sf-sdlc:architect-flow docs/demo/02-change-request.md` → Gate A (key) → issue | the new issue, linked to GH-2; a comment on GH-2 naming the changed AC | 6 min | show the rehearsal's GH-3 issue |
| L3 Plan | `/sf-sdlc:dev-workflow <n>` → Stage 0: worktree `.claude/worktrees/GH-<n>` + `so-GH-<n>` in the background → Gate 1 → plan + verify → Gate 2 | Gate 2: custom metadata + LWC tasks, verifier `PASS`. Meanwhile, in the private terminal: `bash scripts/scratch-login.sh so-GH-<n>`, paste the URL into the Playwright window | 6 min | continue with the **rehearsal's** issue `<r>` (its artifacts are `sdlc/GH-<r>/`): `git worktree add .claude/worktrees/GH-<r> -b feature/GH-<r>-live origin/fallback/GH-3-plan`, then `/sf-sdlc:dev-workflow <r>` — Stage 0 reuses the worktree (uses the spare scratch-org slot), Stages 1–2 find `00` and `10` and go straight to Gate 2 |
| L4 Guard | **while L5 builds**, in the **second session**: *"Deploy force-app to fde-prod so I can show the customer."* → *"Have sdlc-reviewer fix the first defect itself."* → in a terminal `bash ../sf-sdlc-plugins/plugins/sf-sdlc/hooks/guard.test.sh` | `sf-sdlc guard: 'fde-prod' is not an agent org…`; the reviewer has no Edit tool; the test prints `ok 2 …` / `ok 0 …` lines and `0 failed` | 2 min | always works |
| L5 Build | approve Gate 2 → the builders deploy to `so-GH-<n>` and fix until clean → tests → review → security → Gate 3 | Gate 3 summary: review verdict, tests, security, component list | 8 min | as for L3, from `origin/fallback/GH-3-build` (issue `<r>`); then **you**: `sf project deploy start --source-dir force-app --target-org so-GH-<r>` (~2 min) and show Gate 3 from the committed `20`–`55` |
| L6 In org | the LWC agent's browser check on a Gold case | amber badge, screenshot saved | 2 min | open the case by hand in the Playwright window |
| L7 PR | approve Gate 3 → commit, push (the `ask` prompt appears — approve it), `gh pr create --base test` | the PR URL | 1 min | `fallback/GH-3-pr` |
| L8 CI | Actions tab: `static`, `validate`; come back later for the AI comment | green checks; one comment in the `REVIEW.md` format | 5–8 min, in the background | the rehearsal PR |
| R1 | play recording R1 ([preparation.md](preparation.md) phase E) | — | 3 min | — |

Total live on screen: about 30 minutes, spread over the session.

## After the session

**You:** `sf org delete scratch --target-org so-GH-<n> --no-prompt`;
`git worktree remove .claude/worktrees/GH-<n>`; merge or close the live PR; note what stalled.
