# Brightline Support

Demo Salesforce project for the FDE University lecture *The AI-Native SDLC, Mapped onto Salesforce*.
A fictional support company; all data is synthetic.

```
raw notes ──▶ GitHub Issue ──▶ design ──▶ plan ──▶ build in scratch org ──▶ tests ──▶ review
                 Gate A          │         Gate 2                                     Gate 3
                                 ▼                                                       │
                       sdlc/GH-<n>/  (one file per stage, committed with the PR)          ▼
                                                     PR to test ──▶ CI gates ──▶ deploy to fde-test
                                                                                         │
                                                     promotion PR to main ──▶ CI gates ──▶ quick deploy to fde-prod
```

- Setup: [docs/setup.md](docs/setup.md)
- Demo script: [docs/demo/runbook.md](docs/demo/runbook.md)
- Agent conventions: [CLAUDE.md](CLAUDE.md)
- The agents, skills and guard hook: the `sf-sdlc` plugin in the `sf-sdlc-plugins` repo

## Gates

| Gate | Where | Blocks |
|---|---|---|
| Jest, Code Analyzer (sev 1–2) | `pr-validate.yml` → `static` | the merge |
| Risk scan — hardcoded IDs, fewer assertions, permission changes | `scripts/ci/risk-scan.sh` | the merge |
| Validate deploy with `RunLocalTests` against the target org | `pr-validate.yml` → `validate` | the merge |
| Required reviewer on the `prod` environment | GitHub environment | the production deploy |
| AI review | `ai-review.yml` | nothing — it comments; a human decides |
