# Demo test plan — tier priority floor and badge

What "correct" means for the demo feature, and how to check it in the task's scratch org. **You**
run it, not the agent: it's the independent check of what the pipeline built. Run it at step B13
of [walkthrough.md](walkthrough.md), before you answer Gate 3. A failure goes back as
`change <what>` at Gate 3, not as a fix by hand.

The expected values follow the [gate answer key](walkthrough.md#gate-answer-key). If a gate was
answered differently, change this file first.

Replace `<n>` with the issue number (`so-GH-14`, for example). Names the design chooses are
written as `<FloorType>` (the custom metadata type) and `<Badge>` (the LWC). Read them from
`sdlc/GH-<n>/15-design.md`.

## 1. Expected values

| Tier | Priority chosen | Priority saved | Badge |
|---|---|---|---|
| Platinum | Low / Medium / High | **High** / **High** / High | purple pill `Platinum`, line `Minimum priority: High` |
| Gold | Low / Medium / High | **Medium** / Medium / High | amber pill `Gold`, line `Minimum priority: Medium` |
| Standard | Low / Medium / High | Low / Medium / High (unchanged) | grey pill `Standard`, no minimum line |
| *(blank)* | Low | Low; tier becomes `Standard` (existing rule) | grey pill `Standard` |

The rule only raises. It applies on create, and on every save that changes priority or tier.

## 2. In-org checks

All commands run in the **private terminal** from the task's worktree
(`.claude/worktrees/GH-<n>`). Badge checks are in the Playwright window, which is already logged
in (walkthrough B7).

### Test data

```bash
# one case per tier × priority, subjects FLOOR-<tier>-<priority>
for t in Standard Gold Platinum; do for p in High Medium Low; do
  sf data create record --target-org so-GH-<n> --sobject Case \
    --values "Subject='FLOOR-$t-$p' Priority=$p Customer_Tier__c=$t Status=New Origin=Web"
done; done
sf data create record --target-org so-GH-<n> --sobject Case \
  --values "Subject='FLOOR-blank-Low' Priority=Low Status=New Origin=Web"

# what was saved
sf data query --target-org so-GH-<n> \
  -q "SELECT Subject, Customer_Tier__c, Priority FROM Case WHERE Subject LIKE 'FLOOR-%' AND (NOT Subject LIKE 'FLOOR-BULK%') ORDER BY Subject"
```

### Checks

| Id | Case | Steps | Expected |
|---|---|---|---|
| T1 | Platinum is raised | the query above | `FLOOR-Platinum-Low` and `FLOOR-Platinum-Medium` are **High** |
| T2 | Gold is raised | same | `FLOOR-Gold-Low` is **Medium** |
| T3 | Higher stays higher | same | `FLOOR-Gold-High` is High: the rule never lowers |
| T4 | Standard untouched | same | `FLOOR-Standard-*` keep High / Medium / Low |
| T5 | No tier | same | `FLOOR-blank-Low`: tier `Standard`, priority Low |
| T6 | Lowering on update | `sf data update record --target-org so-GH-<n> --sobject Case --where "Subject='FLOOR-Platinum-High'" --values "Priority=Low"`, then rerun the query | still **High**, no error |
| T7 | Tier change | `sf data update record --target-org so-GH-<n> --sobject Case --where "Subject='FLOOR-Standard-Low'" --values "Customer_Tier__c=Platinum"`, then rerun the query | now **High** |
| T8 | Bulk 251 | anonymous Apex below, then the count query | no error; Standard/Low 84, Gold/Medium 84, Platinum/High 83 |
| T9 | Configuration, not code | in the Playwright window: Setup → Custom Metadata Types → `<FloorType>` → Manage Records → Gold → set the minimum to **High** → Save. Create `FLOOR-Gold-Low-2` (Gold, Low). Then set the record back to Medium | `FLOOR-Gold-Low-2` is saved as **High**: the rule reads the record, not a constant |
| T10 | Badge, Platinum | open `FLOOR-Platinum-Low` in the Playwright window | purple `Platinum` pill; `Minimum priority: High` |
| T11 | Badge, Gold and Standard | open `FLOOR-Gold-Low`, then `FLOOR-Standard-Low` | amber `Gold` + `Minimum priority: Medium`; grey `Standard`, no minimum line |
| T12 | Agent access | `sf data query --target-org so-GH-<n> -q "SELECT SetupEntityId FROM SetupEntityAccess WHERE Parent.Name = 'Support_Agent' AND SetupEntityType = 'ApexClass'"`, then compare with the badge's Apex class in `35-metadata.md` | the badge's controller class is granted by `Support_Agent`, not by a profile |
| T13 | Apex tests | `sf apex run test --target-org so-GH-<n> --test-level RunLocalTests --code-coverage --wait 10` | all pass |
| T14 | Tests prove the rule | as in T9, set the **Platinum** record's minimum to **Low**; rerun T13; set it back to High | at least one test **fails** and names Platinum. If all still pass, the tests check what the code does, not the AC: send it back at Gate 3 |
| T15 | LWC test | `npm run test:unit` | the badge's Jest test passes |
| T16 | Artifacts | read `sdlc/GH-<n>/25-tests.md` and `30-review.md` | an inversion table (every AC has a test that fails when the rule is broken); review verdict `Ready for human review` |

### Bulk insert (T8)

```bash
cat > /tmp/floor-bulk.apex <<'EOF'
List<String> tiers = new List<String>{ 'Standard', 'Gold', 'Platinum' };
List<Case> cases = new List<Case>();
for (Integer i = 0; i < 251; i++) {
    cases.add(new Case(Subject = 'FLOOR-BULK-' + i, Priority = 'Low', Status = 'New',
                       Origin = 'Web', Customer_Tier__c = tiers[Math.mod(i, 3)]));
}
insert cases;
EOF
sf apex run --target-org so-GH-<n> --file /tmp/floor-bulk.apex | grep -iE 'success|error'
sf data query --target-org so-GH-<n> \
  -q "SELECT Customer_Tier__c, Priority, COUNT(Id) n FROM Case WHERE Subject LIKE 'FLOOR-BULK%' GROUP BY Customer_Tier__c, Priority"
```

No cleanup needed: the scratch org is deleted in walkthrough C5.

## 3. Pipeline checks (walkthrough B15)

| Id | Where | Expected |
|---|---|---|
| P1 | PR to `test` → `static` | first red: *permission metadata changed … add the 'permissions-reviewed' label*. After you review the permission diff and add the label: Jest, Code Analyzer, risk scan green |
| P2 | `validate` | check-only deploy with `RunLocalTests` green against `fde-test`; artifact `validated-job-id` uploaded |
| P3 | AI review | exactly one comment in the `REVIEW.md` format; the job had no Salesforce secrets |
| P4 | `fde-test` unchanged after the rehearsal | a new Platinum Low case in `fde-test` stays **Low**: the PR was never merged, so the feature isn't in QA |
