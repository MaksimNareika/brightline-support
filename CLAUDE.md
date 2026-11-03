# Brightline Support — Salesforce project

Service Cloud project for a fictional support company. Demo project for FDE University; all data is
synthetic.

## Orgs

| Alias | What | Who deploys |
|---|---|---|
| `fde-prod` | Developer Edition org, production | CI only, on merge to `main` |
| `fde-test` | Developer Edition org, dev and test. Instance URL: `<fill in after setup>` | the agent while building; CI on merge to `test` |

The agent deploys to `fde-test` only, never to `fde-prod`. A hook enforces it; do not look for a way
around it. In a real project the agent's org is a scratch org or a dev sandbox per developer; this
demo shares one org to keep setup small.

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
sf project deploy start --target-org fde-test --source-dir force-app
sf apex run test --target-org fde-test --test-level RunLocalTests --code-coverage --wait 10
npm run test:unit
sf code-analyzer run --workspace force-app --severity-threshold 2 --view table
```

## Landmines

- `BusinessHoursCalculator` exists in `test` but has not been promoted to `main` yet (GH-1). Code that
  uses it cannot reach production until GH-1 does. Run the deploy preflight before a promotion PR.
- The org's default Business Hours record is 24/7 in a new Developer Edition org. Set it to 09:00–18:00
  Mon–Fri in both orgs, or every business-hours calculation equals wall-clock time.

## Checking in the org

The browser (Playwright MCP) is logged in to `fde-test` before a session starts. Navigate to the
instance URL above; never generate a login URL.

## Pipeline artifacts

`sdlc/GH-<n>/` — see the `artifact-contract` skill of the `sf-sdlc` plugin.
