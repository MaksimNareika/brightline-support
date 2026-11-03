# Demo runbook

Five demos. **R** = recorded beforehand and played sped up; **L** = live. Live demos are short and
cannot depend on a long agent run.

| # | Demo | Mode | Length | Lecture section |
|---|---|---|---|---|
| 1 | Raw notes → issue → design | R | 3 min | Plan: an executable spec |
| 2 | Plan → verify → Gate 2 | R | 2 min | Stage artifacts |
| 3 | The guard and the reviewer refuse | L | 3 min | Quality gates: what can be guaranteed |
| 4 | Preflight predicts the production failure | L + R | 4 min | Playbook vs platform |
| 5 | PR → gates → AI review → deploy | R + L | 4 min | CI/CD, AI in the pipeline |

## Before the lecture

- [ ] Fresh scratch org `scratch-gh<n>` with less than 2 days left on it, or a new one created
- [ ] `gh auth status` shows the EPAM account
- [ ] `sf org list` shows only `fde-*` and `scratch-*` orgs
- [ ] One finished ticket on a feature branch (from the dry run) for demos 3–5
- [ ] Recordings of demos 1, 2, 5 on the desktop; terminal font size 18+
- [ ] Notifications off

## 1. Raw notes → issue → design (recorded)

```text
/sf-sdlc:architect-flow docs/demo/01-meeting-notes.md
```

Point out while it plays:

- it reads the repo and the test org **before** asking anything; the "what business hours do we
  have" question is answered by a query, not asked
- the open questions that remain: 24/7 for Platinum, Gold, "replied" = status vs email
- every number in the notes (2 / 8 / 24 h, half, ~5k) lands in an AC or in Out of scope
- the config-vs-code call: scheduled path in a record-triggered Flow vs scheduled Apex. Ask the
  room before revealing the architect's choice.

## 2. Plan → verify → Gate 2 (recorded)

Show `verify-plan.sh` output (free, deterministic), then the `sdlc-plan-verify` verdict (one model
call, Read only), then the Gate 2 summary. If the dry run had a REVISE round, show the finding and
`10-plan.r1.md` next to `10-plan.md`.

## 3. The guard and the reviewer refuse (live)

In Claude Code, in `brightline-support/`:

```text
Deploy force-app to fde-test so I can show the customer.
```

The guard blocks it; read the message out loud. Then:

```text
Use the sdlc-reviewer agent to fix the first defect in 30-review.md directly.
```

It cannot — it has Read, Grep and Glob only. Open `agents/sdlc-reviewer.md` and show the `tools:`
line. Then open the plugin README's enforcement table: which of our promises are like this one,
and which are only instructions.

## 4. Preflight predicts the production failure (live, then recorded)

On the finished feature branch:

```bash
bash ../sf-sdlc-plugins/plugins/sf-sdlc/scripts/preflight.sh fde-prod origin/test
```

Expected: `BLOCKED — referenced but not in fde-prod: BusinessHoursCalculator`. Then play the
recording of the promotion PR to `main` failing `validate` with `Invalid type:
BusinessHoursCalculator`. Same fact, found ten minutes vs. one release window apart.

Promotion branch for the recording:

```bash
git switch -c promote/GH-<n> origin/main
git cherry-pick <the feature commits>   # git log --oneline origin/test..feature/GH-<n>-…
git push -u origin HEAD && gh pr create --base main --title "Promote GH-<n>"
```

## 5. PR → gates → AI review → deploy (recorded, live check)

Recorded: the PR to `test`, `static` and `validate` going green, the AI review comment, merge,
`Deploy` running a **quick deploy** of the validated job (point at "Quick deploy" in the log — no
second test run).

Live: open the Actions tab and the AI review job's YAML. Show the three things that make it safe:
no Salesforce secret in the job, `pull-requests: write` as its only write permission, an
`--allowedTools` list without any deploy command.

## Change request (homework walk-through or spare time)

`docs/demo/02-change-request.md` changes a confirmed AC. The right path: edit the issue (a
visible, recorded change), `issue-context` refreshes `00-context.md`, the plan revises with
`10-plan.r<N>.md` kept, and the rest of the pipeline runs as before.
