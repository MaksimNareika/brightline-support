# Demo runbook

One live task woven through the lecture, plus two short live checks. The agent works while the
lecturer talks; each gate is the point where the lecture comes back to the screen.

- **Built before the lecture (dry run):** GH-2 *First-response SLA* from
  `docs/demo/01-meeting-notes.md`, merged to `test`, deployed to `fde-test` by CI.
- **Live:** GH-3, the change request in `docs/demo/02-change-request.md` (Gold gets 75%, amber
  badge under 30 minutes).
- **Fallback:** a branch for every stage of GH-3, made in the rehearsal (below), plus a screen
  recording of the whole live segment.

## Dry run — GH-2 (a week before)

```text
/sf-sdlc:architect-flow docs/demo/01-meeting-notes.md
/sf-sdlc:dev-workflow <n>
```

At **Gate 2**, check that tier multipliers and the badge thresholds live in **custom metadata**, not
in Apex constants. If not, answer `change: move multipliers and thresholds to custom metadata`.
That is what keeps GH-3 small enough to run live — and steering at the gate is itself a lecture
point.

Merge the PR to `test`, watch `Deploy` quick-deploy to `fde-test`. Keep the session's timings and
token counts (`/usage`) for the slides.

## Rehearsal — GH-3 (two days before)

Run the live segment end to end with a stopwatch. At each step, push a fallback branch:

| After | Fallback branch | Contains |
|---|---|---|
| Gate A | — | issue GH-3 exists (keep it; close it after) |
| Gate 2 | `fallback/GH-3-plan` | `sdlc/GH-3/00`, `10` |
| Build + review | `fallback/GH-3-build` | the code, `20`–`35`, `55` |
| PR | `fallback/GH-3-pr` | the PR (open, as draft) with CI green and the AI review comment |

Then reset: delete `feature/GH-3-*`, close the rehearsal PR, redeploy `test` to `fde-test` so the
org is back to GH-2, edit GH-3 back to its draft text or delete it, uninstall the plugin.

## Live segment

| Step | Command / action | ~Time | If it stalls |
|---|---|---|---|
| L1 Install | `/plugin marketplace add <epam-org>/sf-sdlc-plugins` → `/plugin install sf-sdlc@fde-sdlc` → `/reload-plugins` → `/agents` | 2 min | marketplace from the local clone: `/plugin marketplace add ../sf-sdlc-plugins` |
| L2 Spec | `/sf-sdlc:architect-flow docs/demo/02-change-request.md` → Gate A → issue GH-3 | 6 min | show the rehearsal's GH-3 |
| L3 Plan | `/sf-sdlc:dev-workflow 3` → Gate 1 → plan + verify → Gate 2 | 6 min | `git switch fallback/GH-3-plan`, rerun the workflow: it finds `00` and `10` and resumes |
| L4 Guard | ask: *"deploy force-app to fde-prod"*; then *"have sdlc-reviewer fix the first defect itself"* | 2 min | always works; no fallback needed |
| L5 Build | approve Gate 2 → Admin / LWC agents deploy to `fde-test` → tests → review → security → Gate 3 | 8 min | `fallback/GH-3-build` |
| L6 In org | the LWC agent's browser check on a Gold case: amber badge, screenshot | 2 min | open the record page by hand |
| L7 PR | approve Gate 3 → commit, push, `gh pr create --base test` | 1 min | `fallback/GH-3-pr` |
| L8 CI | Actions tab: `static`, `validate`; return later for the AI review comment | 5–8 min, in background | the rehearsal PR |

Total on screen: about 30 minutes, spread over six lecture sections.

## Short live checks

**Preflight** (closing section), on the GH-2 branch:

```bash
bash ../sf-sdlc-plugins/plugins/sf-sdlc/scripts/preflight.sh fde-prod origin/test
```

Expected `BLOCKED — … BusinessHoursCalculator`. Then the recording of the promotion PR to `main`
failing `validate` with `Invalid type: BusinessHoursCalculator`.

Promotion branch for that recording:

```bash
git switch -c promote/GH-2 origin/main
git cherry-pick <GH-2 commits>          # git log --oneline origin/main..origin/test
git push -u origin HEAD && gh pr create --base main --title "Promote GH-2"
```

## Before the session

- [ ] Demo macOS user; notifications off; terminal and editor font 18+
- [ ] `gh auth status` → EPAM account; `sf org list` → only `fde-*`
- [ ] `env | grep ANTHROPIC_ | cut -d= -f1` → nothing pointing at a client gateway
- [ ] Plugin **not** installed (`/plugins`)
- [ ] Playwright browser logged in to `fde-test`
- [ ] `fde-test` holds GH-2, not GH-3; a Gold case and a Platinum case exist
- [ ] Fallback branches pushed; recording on the desktop
- [ ] Claude Code session started in `brightline-support/`, `/clear`ed
