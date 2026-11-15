# Demo preparation

Everything between a working environment (`docs/setup.md`, smoke test green) and the live session.
The live session itself is [runbook.md](runbook.md); the step-by-step explanation of every mechanism
is [walkthrough.md](walkthrough.md); what "correct" means for the features is
[test-plan.md](test-plan.md).

- **GH-2** — *First-response SLA*, the base feature, built before the lecture from
  [01-meeting-notes.md](01-meeting-notes.md).
- **GH-3** — the live change request from [02-change-request.md](02-change-request.md): Gold gets 75%
  of the time; the badge turns amber under 30 minutes.
- **GH-2 and GH-3 are names, not issue numbers.** Issues and PRs share one counter and a number is
  never reused, so the real numbers are whatever GitHub hands out. Write them down after each phase.
  The business hours helper is the real issue **#3** — unrelated to the name GH-3.

Dates are relative to the lecture day **L**.

## Timeline

| When | Phase | What | Output |
|---|---|---|---|
| L-15 | — | [Readiness checks](#readiness-checks) | all green; `fde-test` outlives L |
| L-14 | A | Dry run GH-2, end to end — follow [walkthrough.md](walkthrough.md) | GH-2 merged to `test`, deployed to `fde-test`; timings |
| L-14 | B | Test GH-2 (test plan §2) in its scratch org, then the smoke subset in `fde-test` | all GH-2 cases pass |
| L-4 | D | Rehearsal GH-3 with a stopwatch | fallback branches; GH-3 in `fde-test` |
| L-4 | E | Recording R1: GH-3 to production | video: merge → `test` → release PR → `prod` |
| L-3 | F | Reset for the live run | `test` and `fde-test` back at GH-2; plugin removed |
| L-1 | G | Readiness checks again + the before-the-session list | all green |
| L | — | Live session: [runbook.md](runbook.md) | — |

Scratch-org budget (Developer Edition Dev Hub: 3 active, 6 new per day; `fde-test` holds one active
slot): A, D and the live run each create one org. Delete each task org when its phase is done.

## Readiness checks

Run at L-15 and again at L-1, off screen. Each line: the command, then what passes.

| # | Check | Command | Passes when |
|---|---|---|---|
| R1 | Production org and Dev Hub | `sf org list` | `fde-prod` `Connected`, marked 🌳 (Dev Hub) |
| R2 | QA org alive past L | `sf org list` | `fde-test` `Active`, expiration date **after L**. If not: recreate it (setup §8, *Recreating `fde-test`*); it rebuilds from `test` and refreshes CI's login |
| R3 | QA org Business Hours | `sf data query -o fde-test -q "SELECT MondayStartTime, MondayEndTime, SaturdayStartTime FROM BusinessHours WHERE IsDefault = true"` | 09:00, 18:00, Saturday empty |
| R4 | No leftovers | `sf org list` · `git worktree list` | no `so-*` org; only the main checkout |
| R5 | Scratch quota | `sf org list limits -o fde-prod \| grep -i scratch` | at least 2 active and 2 daily remaining (on L: the live org + a spare) |
| R6 | CI can reach `fde-test` | `gh run list --workflow deploy.yml --branch test --limit 1` | the last run is ✓ and newer than the last `fde-test` recreation. Otherwise run `bash scripts/fde-test-ci-auth.sh` |
| R7 | CI can reach `fde-prod` | `gh run list --workflow deploy.yml --branch main --limit 1` · `openssl x509 -enddate -noout -in ~/fde-ci/server.crt` | last run ✓; certificate valid past L |
| R8 | Gates on `main` and `test` | `for b in main test; do gh api repos/MaksimNareika/brightline-support/branches/$b/protection --jq '.required_status_checks.contexts'; done` | `["static","validate"]` for both |
| R9 | Production approval | `gh api repos/MaksimNareika/brightline-support/environments/prod --jq '[.protection_rules[].type]'` | `["required_reviewers"]` |
| R10 | Claude locally and in CI | `claude -p "say ok"` · the latest PR has an AI review comment | `ok`; a comment exists |
| R11 | Plugin clonable | `git ls-remote https://github.com/MaksimNareika/sf-sdlc-plugins.git \| head -1` | prints a ref (else `gh auth setup-git`) |
| R12 | Browser tool | `npx -y @playwright/mcp@0.0.83 --help >/dev/null && echo ok` | `ok` |
| R13 | Guard | `bash ../sf-sdlc-plugins/plugins/sf-sdlc/hooks/guard.test.sh` | `0 failed` |

---

## Phase A — dry run GH-2

Follow [walkthrough.md](walkthrough.md) from start to end: it is phase A with every step explained
(what runs, which script or hook, where to show it). Answer the gates from the
[gate answer key](runbook.md#gate-answer-key). Record per stage: minutes, `/usage`, anything that
needed a correction (`process-log check`).

**Done when:** GH-2 is merged to `test`, CI deployed it to `fde-test`, phase B passed, `so-GH-2` and
its worktree are deleted (you), and the timings are written down. Keep GH-2's feature branch until
phase D is done.

## Phase B — test GH-2

[test-plan.md](test-plan.md) §2 in `so-GH-2` **before Gate 3** (a failure goes back as `change` at
Gate 3, not as a hand fix), then the smoke subset in `fde-test` after the merge. After the dry run,
write the real field names into `scripts/demo/check-sla.apex` (test plan §1) and merge it to
`test`, so the rehearsal and the live run use the same check.

## Phase D — rehearsal GH-3

Run the live steps L1–L8 of [runbook.md](runbook.md) exactly as on the day, with a stopwatch. The
plugin is already installed, so L1 is a check only. After each step, push a fallback branch:

| After | Fallback | Contains |
|---|---|---|
| Gate A | — | the GH-3 issue (keep it) |
| Gate 2 | `fallback/GH-3-plan` | `sdlc/GH-3/00`, `10` |
| Build + review | `fallback/GH-3-build` | the code, `20`–`35`, `55`, screenshot |
| PR | `fallback/GH-3-pr` | the PR, kept open as draft, CI green, the AI comment |

Then test plan §3 in `so-GH-3`, merge the PR to `test` (you), and the §3 smoke subset in `fde-test`.

## Phase E — recording R1: GH-3 to production

The "whole pipeline" of the practice exercise. Record end to end; cut the waiting.

1. **You:** `gh pr create --base main --head test --title "Release 1: #3, GH-2, GH-3"`. A release
   promotes everything in `test` together, so the helper (#3) travels with the change that uses it.
2. `static` green; `validate` waits for the `prod` reviewer → approve → green against `fde-prod`;
   the AI review comment.
3. Merge. `Deploy` waits on the `prod` environment → approve as the required reviewer.
4. Quick deploy to `fde-prod` succeeds (the validated job, no second test run).
5. In `fde-prod`: a Gold, Medium case gets a respond-by 6 business hours out (test plan T3-02).

**Done when:** the recording shows steps 1–5. From now on `fde-prod` holds #3, GH-2 and GH-3, and
is not reset.

## Phase F — reset for the live run

The live run needs `test` and `fde-test` back at GH-2, a free scratch-org slot and no plugin.

| # | Do (you) | Check |
|---|---|---|
| F1 | `sf org delete scratch --target-org so-GH-3 --no-prompt`; `git worktree remove .claude/worktrees/GH-3`; delete `feature/GH-3-*` locally and on GitHub (keep the `fallback/*` branches) | R4 passes |
| F2 | revert GH-3 on `test`: branch from `test`, `git revert -m 1 <GH-3 merge commit>`, PR to `test`, merge | CI deploys to `fde-test`; a Gold Medium case there gets 8 h again (test plan T2-05) |
| F3 | if `sdlc/GH-3/35-metadata.md` lists components GH-3 **added** (not changed), the revert deploy does not remove them: recreate `fde-test` from the reverted `test` (setup §8; costs a daily slot, refreshes CI's login) | the `fde-test` badge shows no amber state |
| F4 | `fde-prod` is **not** reset: it keeps Release 1. The live PR goes to `test` only | — |
| F5 | remove the plugin **and** its marketplace, so L1 installs both from nothing. In a terminal in `brightline-support/`: `claude plugin uninstall sf-sdlc@fde-sdlc --scope local`, then `claude plugin marketplace remove fde-sdlc`; close every Claude Code session | `claude plugin list` shows no `sf-sdlc`; `claude plugin marketplace list` shows no `fde-sdlc`; in a new session `/agents` lists no `sdlc-*` agent |
| F6 | R5 | at least 2 active and 2 daily left for L |

After the lecture `main` holds GH-3 while `test` holds its revert plus the live GH-3 PR. Settle it
then: merge the live PR, and the next release PR brings `test` and `main` back together.

## Phase G — before the session (L-1 and L)

- [ ] Readiness checks R1–R13 green (today)
- [ ] Plugin **not** installed (F5) — L1 starts from nothing
- [ ] `fde-test` holds GH-2, not GH-3: a Gold Medium case gets 8 h
- [ ] Fallback branches pushed; the real issue numbers of GH-2 and the rehearsal GH-3 written down
- [ ] Recording R1 on the desktop
- [ ] Demo macOS user; notifications off; terminal and editor font 18+
- [ ] Off screen: `gh auth status` shows the account that owns the repos
- [ ] A second terminal, **not** shared, in `brightline-support/` for `scratch-login.sh`
- [ ] Claude Code started **in a terminal** (`claude`; the VS Code extension has no `/plugin`), in
      `brightline-support/`, on `test`, `/clear`ed
- [ ] A **second** terminal Claude Code session in `brightline-support/` for L4 (after L1:
      `/reload-plugins` there)
- [ ] Browser tabs: the repo's Actions tab, PR list, Settings → Environments → prod
