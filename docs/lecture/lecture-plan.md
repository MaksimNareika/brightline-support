# Lecture plan — The AI-Native SDLC, Mapped onto Salesforce

FDE University, module 7. 90 minutes online, recorded: about 75 minutes of content and 15 minutes of
buffer for the live demo. The deck (25 slides, with speaker notes) is kept outside this repo.

Related: [preparation](../demo/preparation.md) · [runbook](../demo/runbook.md) (the live steps
L1–L8) · [walkthrough](../demo/walkthrough.md) (how every step works) ·
[test plan](../demo/test-plan.md).

## The lecture in one paragraph

On Salesforce the irreversible step is a production deploy, and half the logic is metadata, so an
AI-native SDLC is a chain of **written stage artifacts** and **gates that sit before the deploy**.
The session runs that chain live on a fictional company: install the plugin, take a change request
from a sentence to an issue, plan, build in a scratch org, check it in the org, review, open a PR,
and watch the CI gates and the AI reviewer. Closing message: know which of your promises are
enforced by the harness, a hook, a script or CI — and which are only a sentence in a prompt.

## Structure

One concept slide and one demo slide per section; the section is the slide's kicker, there are no
divider slides. The agent works while you talk: the build (L5) starts before the tests section and
comes back at Gate 3; CI (L8) runs during the AI-in-the-pipeline section.

| # | Section | Slide | One message | Demo | Min |
|---|---|---|---|---|---|
| 1 | — | Title | — | — | 0.5 |
| 2 | Outcome | What we build today | the module's practice exercise, line by line, next to the demo step that does it | — | 2 |
| 3 | Demo project | Today's demo | Brightline Support (fictional); GH-2 built before, GH-3 live; the names used later: tickets, scratch org, QA org, production org | — | 2 |
| 4 | Toolkit | What we use, and how it fits | Claude Code + the `sf-sdlc` plugin (skills, agents, hook, scripts); browser, `sf` CLI, GitHub CLI; who may change which org | — | 2 |
| 5 | Demo · L1 | Install the plugin | one install brings the agents, skills and the hook; `/agents`, `/hooks` | **L1** | 2 |
| 6 | Playbook vs platform | Gates move before the deploy | repo world: a merge can be reverted; Salesforce: the org is a second source of truth and a production deploy cannot be reverted, so every gate sits before it. Path: scratch org → PR → QA org → release → production | — | 4 |
| 7 | Plan | From meeting notes to acceptance criteria | GH-2's notes vs AC2 (Given/When/Then); negative criteria, AC → test, every number lands somewhere, a changed spec is a visible edit, review the plan not the diff | — | 4 |
| 8 | Demo · L2 | Change request → ticket | the architect drafts, Gate A, issue; the changed AC is recorded on GH-2 | **L2** | 6 |
| 9 | Stage artifacts | One file per stage, one writer each | the artifact map and its four rules: one writer, point don't paste, missing input, findings for upstream | — | 3 |
| 10 | Demo · L3 | Plan, verify, Gate 2 | `verify-plan.sh` (a script, no tokens) → `sdlc-plan-verify` (read-only agent) → Gate 2 shows tasks and the AC mapping | **L3** | 5 |
| 11 | Prototype → design → build | How the build works | what a prototype skips; the design decides config vs code; Stage 0 = worktree + scratch org; Admin → Apex → LWC; parallel tasks = more worktrees | — | 3 |
| 12 | Room question | Flow or Apex? | the escalation: a scheduled path vs scheduled Apex | — | 2 |
| 13 | Demo · L5 start | Approve Gate 2 — the build starts | the builders deploy to `so-GH-<n>`; we come back at Gate 3 | **L5** | 1 |
| 14 | Tests | A test that passes vs a test that proves | inversion, bulk 251, `runAs`; 75% coverage is a floor | — | 3 |
| 15 | Quality gates | Five layers of enforcement | harness, hook, script, CI, instruction — only the instruction can be skipped | — | 2 |
| 16 | Quality gates | How a hook works vs an instruction | PreToolUse → `guard.sh` → exit 2 + reason; its limit: it sees the command line only. An instruction is text in the context that nothing checks | — | 3 |
| 17 | Quality gates | Agent defect → the gate that catches it | invented field, missing sharing, weakened test, permission change, hardcoded ID; org drift as an idea, not in the demo | — | 2 |
| 18 | Demo · L4 | The guard and the reviewer refuse | second session: a deploy to `fde-prod` is blocked; the reviewer cannot edit; `guard.test.sh` | **L4** | 2 |
| 19 | Review and fix loop | What review is for, and the loop | spec fit, config vs code, mixed batches, tests that assert the code; the reviewer has its own context and read-only tools; two fix rounds, then a human | — | 3 |
| 20 | Demo · L5 / L6 | Gate 3 and the check in the org | review table, tests, security pass; the amber badge in the scratch org, with a screenshot | **L5–L6** | 4 |
| 21 | CI/CD | Validate once, deploy the validated job | static → validate → merge → quick deploy to the QA org → release PR → validate against production → required reviewer → quick deploy. L7 (commit, push, PR) runs here | **L7** | 3 |
| 22 | AI in the pipeline | One real job, two that fit the pattern | the PR review job: trigger, input, permissions, what it cannot do; triage and release notes as ideas; no org secrets in AI jobs | — | 3 |
| 23 | Demo · L8 / R1 | Checks, AI comment, then to production | the PR's checks and AI comment; recording R1: release PR → production reviewer → quick deploy | **L8, R1** | 5 |
| 24 | Portable takeaway | Take this to any stack | five takeaways, each next to where the demo showed it | — | 3 |
| 25 | Discussion | Your project, homework, reading | three questions; the homework; read next | — | 4 |

About 75 minutes. **If behind at L2:** show the rehearsal's GH-3 issue. **If behind at L5:** the
build fallback in the runbook.

### Discussion prompts

- After the plan section: "What's the last requirement that changed silently on your project?"
- After the quality gates: "Name one promise in your setup that is only an instruction."
- Last slide: "Where would your first gate go, and what would it block?"

## The demo task

**Brightline Support** — a fictional support company on Service Cloud; all data is synthetic.

- **GH-2 *First-response SLA*, built before the session** from
  [01-meeting-notes.md](../demo/01-meeting-notes.md): every case gets a respond-by time — High 2 h,
  Medium 8 h, Low 24 h of business hours, Platinum half. Late cases go to the Escalations queue and
  are flagged; a countdown badge shows on the case page; the integration user is excluded. It
  reuses the business hours helper (#3). The notes are deliberately messy ("24h?", Platinum 24/7,
  Gold "park it", what "replied" means), so the architect has to research the repo and the org first.
- **GH-3 *Change request after UAT*, live** from [02-change-request.md](../demo/02-change-request.md):
  Gold gets 75% of the time; the badge turns amber under 30 minutes. It changes a confirmed
  acceptance criterion, so it goes through the issue, not straight into code.

Live flow (exact steps in the [runbook](../demo/runbook.md)): install the plugin → change request →
issue → Stage 0 (worktree + scratch org) → plan and Gate 2 → guard demo → build → Gate 3 and the check
in the org → PR → CI and the AI review → recording R1 to production.

## Reading for the presenter

| For | Resource | Why | Time |
|---|---|---|---|
| the whole arc | [The AI-Native SDLC Playbook](https://claude.com/blog/the-ai-native-sdlc-playbook) | the module's backbone: one committed artifact per stage; "the agent may act up to the production gate and cannot pass it" | 30 min |
| CI/CD | [Agentic coding is straining CI](https://claude.com/blog/agentic-coding-is-straining-ci-heres-how-we-scaled-test-impact-analysis-at-anthropic) | why the cost of a gate matters | 10 min |
| Tests | [`platform-apex-test-generate` SKILL.md](https://raw.githubusercontent.com/forcedotcom/sf-skills/main/skills/platform-apex-test-generate/SKILL.md) | Salesforce's own definition of a good Apex test; compare with the `sdlc-tests` agent | 15 min |
| AI in the pipeline | [Claude Code GitHub Actions](https://code.claude.com/docs/en/github-actions) | the mechanics behind an AI job in CI: auth, triggers, permissions | 20 min |
| AI in the pipeline | [The lethal trifecta](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/) | the one-slide argument for "no secrets in the AI job" | 10 min |
| Plan | [GitHub Spec Kit](https://github.com/github/spec-kit) | the portable version of an executable spec | 15 min |
| optional | [Claude Code best practices](https://www.youtube.com/watch?v=gv0WHhKelSE) | explore → plan → code → commit, from the team that built it | 30 min |
