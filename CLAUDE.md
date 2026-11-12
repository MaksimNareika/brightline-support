# Brightline Support — Salesforce project

Service Cloud project for a fictional support company. Demo project for FDE University; all data is
synthetic.

## Orgs

| Alias | What | Who deploys |
|---|---|---|
| `so-GH-<n>` | Scratch org, one per task, created at Stage 0 of the dev workflow | the agent, while building that task |
| `fde-test` | Scratch org, QA, long-lived (recreated every ≤ 30 days) | CI only, on merge to `test` |
| `fde-prod` | Developer Edition org, production **and Dev Hub** | CI only, on merge to `main` |

The agent deploys to its task's `so-GH-<n>` only, never to `fde-test` or `fde-prod`. A hook enforces
it; do not look for a way around it. The Dev Hub allows few active scratch orgs and `fde-test` holds
one of them: create no scratch org other than the task's own.

## Branches

`feature/GH-<n>-<slug>` from `test` → PR to `test` → promotion PR to `main`. Never commit to `test` or
`main` directly.

## Conventions

- One trigger per object; logic in `<Object>TriggerHandler extends TriggerHandler`.
- Every class declares sharing. User-facing SOQL/DML runs in user mode.
- Configuration (thresholds, hours, mappings) in custom metadata, never hardcoded.
- Test data through `TestDataFactory`. Tests assert the business rule and carry a message.
- Access through the `Support_Agent` permission set, never profiles.
- `Customer_Tier__c` is always set on a Case: the trigger defaults it to `Standard`.

## Verify

```bash
sf project deploy start --target-org so-GH-<n> --source-dir force-app
sf apex run test --target-org so-GH-<n> --test-level RunLocalTests --code-coverage --wait 10
npm run test:unit
sf code-analyzer run --workspace force-app --severity-threshold 2 --view table
```

## Landmines

- `BusinessHoursCalculator` (GH-1) is in `test` but not in `main` yet. Promotion to `main` is a release
  PR from `test`, so everything in `test` ships together. Never cherry-pick single tickets to `main`:
  a ticket that uses another ticket's class would fail production validation with "Invalid type".
- A new org's default Business Hours record is 24/7, which makes every business-hours calculation
  equal wall-clock time. `fde-prod` is set to 09:00–18:00 Mon–Fri by hand; every scratch org gets it
  from its creation script. If a business-hours result equals clock time, check the org's default
  Business Hours before the code.

## Checking in the org

A human logs the browser (Playwright MCP) in to the task's scratch org after Stage 0. Use the open
session; never generate a login URL.

## Pipeline artifacts

`sdlc/GH-<n>/` — see the `artifact-contract` skill of the `sf-sdlc` plugin.
