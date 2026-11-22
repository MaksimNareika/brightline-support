# Lecture plan — The AI-Native SDLC, Mapped onto Salesforce

FDE University, module 7. 90 minutes online, recorded: about 75 minutes of content and 15 minutes of
buffer for the live demo. The deck (25 slides, with speaker notes) is kept outside this repo.

Related: [walkthrough](../demo/walkthrough.md) (rehearsal, reset and the live steps L1–L8, each
explained) · [test plan](../demo/test-plan.md).

## The lecture in one paragraph

On Salesforce the irreversible step is a production deploy, and half the logic is metadata, so an
AI-native SDLC is a chain of **written stage artifacts** and **gates that sit before the deploy**.
The session runs that chain live on a fictional company: install the plugin, take a short Slack
request to an issue, plan, build in a scratch org, check it in the org, review, open a PR,
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
| 3 | Demo project | Today's demo | Brightline Support (fictional); one small feature, built live from a Slack message; the names used later: tickets, scratch org, QA org, production org | — | 2 |
| 4 | Toolkit | What we use, and how it fits | Claude Code + the `sf-sdlc` plugin (skills, agents, hook, scripts); browser, `sf` CLI, GitHub CLI; who may change which org | — | 2 |
| 5 | Demo · L1 | Install the plugin | one install brings the agents, skills and the hook; `/agents`, `/hooks` | **L1** | 2 |
| 6 | Playbook vs platform | Gates move before the deploy | repo world: a merge can be reverted; Salesforce: the org is a second source of truth and a production deploy cannot be reverted, so every gate sits before it. Path: scratch org → PR → QA org → release → production | — | 4 |
| 7 | Plan | From a request to acceptance criteria | Lee's message vs the AC (Given/When/Then); research before asking; negative criteria ("never lowers"), AC → test, every rule lands in an AC or Out of scope, review the plan not the diff | — | 4 |
| 8 | Demo · L2 | Request → ticket | the architect researches the repo first, asks only what it can't settle, Gate A, issue | **L2** | 6 |
| 9 | Stage artifacts | One file per stage, one writer each | the artifact map and its four rules: one writer, point don't paste, missing input, findings for upstream | — | 3 |
| 10 | Demo · L3 | Plan, verify, Gate 2 | `verify-plan.sh` (a script, no tokens) → `sdlc-plan-verify` (read-only agent) → Gate 2 shows tasks and the AC mapping | **L3** | 5 |
| 11 | Prototype → design → build | How the build works | what a prototype skips; the design decides config vs code; Stage 0 = worktree + scratch org; Admin → Apex → LWC; parallel tasks = more worktrees | — | 3 |
| 12 | Room question | Flow or Apex? | the priority floor: a before-save Flow vs the existing trigger handler (one automation per object, order of execution) | — | 2 |
| 13 | Demo · L5 start | Approve Gate 2 — the build starts | the builders deploy to `so-GH-<n>`; we come back at Gate 3 | **L5** | 1 |
| 14 | Tests | A test that passes vs a test that proves | inversion, bulk 251, `runAs`; 75% coverage is a floor | — | 3 |
| 15 | Quality gates | Five layers of enforcement | harness, hook, script, CI, instruction — only the instruction can be skipped | — | 2 |
| 16 | Quality gates | How a hook works vs an instruction | PreToolUse → `guard.sh` → exit 2 + reason; its limit: it sees the command line only. An instruction is text in the context that nothing checks | — | 3 |
| 17 | Quality gates | Agent defect → the gate that catches it | invented field, missing sharing, weakened test, permission change, hardcoded ID; org drift as an idea, not in the demo | — | 2 |
| 18 | Demo · L4 | The guard and the reviewer refuse | second session: a deploy to `fde-prod` is blocked; the reviewer cannot edit; `guard.test.sh` | **L4** | 2 |
| 19 | Review and fix loop | What review is for, and the loop | spec fit, config vs code, mixed batches, tests that assert the code; the reviewer has its own context and read-only tools; two fix rounds, then a human | — | 3 |
| 20 | Demo · L5 / L6 | Gate 3 and the check in the org | review table, tests, security pass; the tier badge on a Platinum case in the scratch org, with a screenshot | **L5–L6** | 4 |
| 21 | CI/CD | Validate once, deploy the validated job | static → validate → merge → quick deploy to the QA org → release PR → validate against production → required reviewer → quick deploy. L7 (commit, push, PR) runs here | **L7** | 3 |
| 22 | AI in the pipeline | One real job, two that fit the pattern | the PR review job: trigger, input, permissions, what it cannot do; triage and release notes as ideas; no org secrets in AI jobs | — | 3 |
| 23 | Demo · L8 | Checks, AI comment, the way to production | the PR's checks, the `permissions-reviewed` label step and the AI comment; the release path (release PR → production reviewer → quick deploy) explained from the CI config, not run | **L8** | 5 |
| 24 | Portable takeaway | Take this to any stack | five takeaways, each next to where the demo showed it | — | 3 |
| 25 | Discussion | Your project, homework, reading | three questions; the homework; read next | — | 4 |

About 75 minutes. **If a step stalls:** the fallbacks in [walkthrough D4](../demo/walkthrough.md#d4--if-a-step-stalls)
(the rehearsal's draft, the `fallback/priority-floor` branch, the rehearsal's PR).

### Discussion prompts

- After the plan section: "What's the last requirement that changed silently on your project?"
- After the quality gates: "Name one promise in your setup that is only an instruction."
- Last slide: "Where would your first gate go, and what would it block?"

## The demo task

**Brightline Support** — a fictional support company on Service Cloud; all data is synthetic.

- **Tier priority floor and badge, live** from [01-feature-request.md](../demo/01-feature-request.md):
  a Platinum customer's case is never below High, a Gold customer's never below Medium; the rule
  applies on create and on every priority or tier change, and only ever raises. The mapping is
  custom metadata. A colored badge on the Case page shows the tier and the minimum priority. The
  request is deliberately short ("probably at least Medium", "shouldn't stay Low", "something
  colourful"), so the architect has to research the repo first and ask only what it can't settle.
- It is rehearsed end to end beforehand, then everything the rehearsal created is removed
  ([walkthrough Part C](../demo/walkthrough.md#part-c--reset-after-the-rehearsal)), so on the day
  nothing is already built.

Live flow (exact steps in the [walkthrough](../demo/walkthrough.md), Part B): install the plugin →
request → issue → Stage 0 (worktree + scratch org) → plan and Gate 2 → guard demo → build → Gate 3
and the check in the org → PR → CI and the AI review.

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
