# Demo test plan

What "correct" means for GH-2 (first-response SLA) and GH-3 (the change request), and how to check
it in an org. Run by **you**, not by the agent: it is the independent check of what the pipeline
built. The expected values follow the gate answer key in `runbook.md`; if a gate was answered
differently, change this file first.

Field, class and permission names come from `sdlc/GH-2/15-design.md`. They are written here as
`<RespondBy>`, `<Breached>`, `<EscalationJob>`, `<BypassPermSet>` — replace them after the dry run.

## 1. Expected values

Business hours: default record, Mon–Fri 09:00–18:00. Values are **business** hours between the
case's `CreatedDate` and its respond-by time.

| Tier | High | Medium | Low | GH-2 multiplier | GH-3 multiplier |
|---|---|---|---|---|---|
| Standard | 2 | 8 | 24 | 1.0 | 1.0 |
| Gold | 2 → **1.5** | 8 → **6** | 24 → **18** | 1.0 | **0.75** |
| Platinum | 1 | 4 | 12 | 0.5 | 0.5 |

Badge on the case page:

| Time left | GH-2 | GH-3 |
|---|---|---|
| 30 min or more | countdown, neutral | countdown, neutral |
| under 30 min | countdown, neutral | **amber** |
| overdue | red | red |

### The check script

A respond-by time depends on when the case was created, so compare **business-hour differences**,
not clock times. Save as `scripts/demo/check-sla.apex` once the field names are known:

```apex
// Prints the business hours between CreatedDate and the respond-by time of every test case.
Id bh = [SELECT Id FROM BusinessHours WHERE IsDefault = true].Id;
for (Case c : [SELECT CaseNumber, Subject, Priority, Customer_Tier__c, CreatedDate, <RespondBy>
               FROM Case WHERE Subject LIKE 'SLA-TEST%' ORDER BY Subject]) {
    Object rb = c.get('<RespondBy>');
    String hours = rb == null ? 'none'
        : String.valueOf((BusinessHours.diff(bh, c.CreatedDate, (Datetime) rb) / 60000) / 60.0);
    System.debug('SLA ' + c.Subject + ' | ' + c.Customer_Tier__c + '/' + c.Priority + ' = ' + hours + ' h');
}
```

```bash
sf apex run --target-org <org> --file scripts/demo/check-sla.apex | grep 'SLA '
```

Allow ±1 minute.

### Test data

```bash
# one case per tier × priority, subjects SLA-TEST-<tier>-<priority>
for t in Standard Gold Platinum; do for p in High Medium Low; do
  sf data create record --target-org <org> --sobject Case \
    --values "Subject='SLA-TEST-$t-$p' Priority=$p Customer_Tier__c=$t Status=New Origin=Web"
done; done
```

Clean up at the end: `sf data delete bulk --target-org <org> --sobject Case --file <ids.csv>`, or
delete the scratch org.

## 2. GH-2 — first-response SLA

| Id | Case | Steps | Expected |
|---|---|---|---|
| T2-01..09 | Targets per tier × priority | create the test data; run the check script | the GH-2 column of §1: Standard and Gold 2 / 8 / 24, Platinum 1 / 4 / 12 |
| T2-10 | No tier | create `SLA-TEST-blank-High` without `Customer_Tier__c` | tier becomes `Standard`; 2 h |
| T2-11 | Priority change recalculates | change `SLA-TEST-Standard-Low` to High | check script: 2 h |
| T2-12 | Integration user excluded | `sf org assign permset --name <BypassPermSet> --target-org <org>`; create `SLA-TEST-bypass-High`; remove the assignment afterwards | `<RespondBy>` empty |
| T2-13 | Bulk 251 | anonymous Apex: insert 251 cases, mixed tiers and priorities, subject `SLA-TEST-BULK-<i>` | no error; `SELECT COUNT() FROM Case WHERE Subject LIKE 'SLA-TEST-BULK%' AND <RespondBy> = null` returns 0 |
| T2-14 | Late, not replied | set `<RespondBy>` of `SLA-TEST-Gold-High` (Status `New`) to an hour ago: `sf data update record --sobject Case --where "Subject='SLA-TEST-Gold-High'" --values "<RespondBy>=$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)" --target-org <org>`; run `<EscalationJob>` on demand | Owner = `Escalations` queue; `<Breached>` = true |
| T2-15 | Late, already replied | same for `SLA-TEST-Gold-Medium`, but first set Status to `Working` | owner unchanged; `<Breached>` = false |
| T2-16 | Badge | open `SLA-TEST-Standard-Medium` (future) and `SLA-TEST-Gold-High` (overdue) | countdown neutral; overdue red |
| T2-17 | Agent access | log in as, or check, the `Support_Agent` permission set | it grants read on the new fields; the badge renders for an agent |
| T2-18 | Apex tests | `sf apex run test --target-org <org> --test-level RunLocalTests --code-coverage --wait 10` | all pass |
| T2-19 | Tests prove the rule | in the scratch org only: set the Platinum multiplier record to 1.0, rerun the tests, then set it back | at least one test **fails** and names Platinum. If all still pass, the tests assert what the code does, not the AC — send it back at Gate 3 |
| T2-20 | Artifacts | read `sdlc/GH-2/25-tests.md` | an inversion table: every AC has a test that fails when the rule is inverted |

**Smoke subset in `fde-test`** (after CI deploys it): T2-02, T2-05, T2-08, T2-14, T2-16. Agents
cannot write data in `fde-test`; you run these.

## 3. GH-3 — change request

Run after the build in `so-GH-3`, before Gate 3, then the smoke subset in `fde-test` after the merge.

| Id | Case | Steps | Expected |
|---|---|---|---|
| T3-01..03 | Gold targets | test data + check script | Gold 1.5 / 6 / 18 |
| T3-04 | Nothing else changed | same run | Standard 2 / 8 / 24, Platinum 1 / 4 / 12 |
| T3-05 | Amber | set `<RespondBy>` of a New case to now + 20 min (`date -u -v+20M +%Y-%m-%dT%H:%M:%SZ`); open it | amber countdown |
| T3-06 | Neutral above 30 min | now + 45 min | neutral |
| T3-07 | Red | an hour ago | red |
| T3-08 | Boundary | read the LWC Jest test | cases at 29:59 (amber) and 30:00 (neutral) exist and pass: `npm run test:unit` |
| T3-09 | Configuration, not code | `git diff origin/test --stat` on the feature branch | the Gold change is a custom metadata record; no Apex constant changed |
| T3-10 | The spec change is visible | open the GH-2 issue | a comment or edit naming the changed AC; the GH-3 issue links to it |
| T3-11 | Regression | T2-12 to T2-15, T2-18 | still pass |

**Smoke subset in `fde-test`:** T3-02, T3-04 (one Platinum case), T3-05.

## 4. Pipeline checks

| Id | Where | Expected |
|---|---|---|
| P1 | PR to `test` → `static` | Jest, Code Analyzer, risk scan green |
| P2 | `org-drift` **[§8]** | green; it fails if `fde-test` holds a version of a changed component that `test` does not |
| P3 | `validate` | deploy validation with `RunLocalTests` green against `fde-test`; artifact `validated-job-id` uploaded |
| P4 | AI review | exactly one comment in the `REVIEW.md` format; the job had no Salesforce secrets |
| P5 | merge → `Deploy` | step **Quick deploy the validated job** succeeded; the full deploy step was skipped |
| P6 | PR to `main` → merge | `Deploy` waits for the `prod` reviewer; nothing deploys before approval |
| P7 | failed `validate` **[§8]** | a triage comment names the cause, the file and the line (runbook phase C: the invented field `Respond_Deadline__c`) |
| P8 | merge to `main` **[§8]** | release notes list the promoted issues, written from `sdlc/GH-<n>/` |
