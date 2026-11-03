# Brightline Support — Salesforce project

Service Cloud project for a fictional support company. Demo project for FDE University; all data is
synthetic.

## Orgs

| Alias | What | Who deploys |
|---|---|---|
| `fde-prod` | Developer Edition org, production. Also the Dev Hub (`fde-devhub`) | CI only, on merge to `main` |
| `fde-test` | Developer Edition org, test / UAT | CI only, on merge to `test` |
| `scratch-gh<n>` | one scratch org per issue | the agent |

The agent deploys to scratch orgs only. A hook enforces it; do not look for a way around it.

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
sf project deploy start --target-org scratch-gh<n> --source-dir force-app
sf apex run test --target-org scratch-gh<n> --test-level RunLocalTests --code-coverage --wait 10
npm run test:unit
sf code-analyzer run --workspace force-app --severity-threshold 2 --view table
```

## Landmines

- `BusinessHoursCalculator` exists in `test` but has not been promoted to `main` yet (GH-1). Code that
  uses it cannot reach production until GH-1 does. Run the deploy preflight before a promotion PR.
- The org's default Business Hours record is 24/7 in a new Developer Edition org. Set it to 09:00–18:00
  Mon–Fri in both orgs, or every business-hours calculation equals wall-clock time.

## Pipeline artifacts

`sdlc/GH-<n>/` — see the `artifact-contract` skill of the `sf-sdlc` plugin.
