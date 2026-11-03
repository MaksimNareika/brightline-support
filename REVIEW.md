# Review policy

What the AI reviewer checks on every PR, and what it leaves alone. Humans review against the same
list; code owners give the final approval.

## Check

1. **Acceptance criteria.** If the PR adds `sdlc/GH-<n>/`, every AC in `00-context.md` is met by the
   diff. Name the AC that is not.
2. **Mixed batches.** Trigger and service logic that is right for one record and wrong for 200 of
   different priorities, tiers or owners.
3. **Tests that prove nothing.** An assertion copied from what the code returns, not from the AC; no
   negative test for a negative AC; no `System.runAs` on a user-facing path.
4. **Conventions in `CLAUDE.md`.** Sharing declared, user mode on user-facing SOQL/DML, configuration
   in custom metadata, access through `Support_Agent`, one trigger per object.
5. **Config vs code.** Apex where a formula, validation rule or Flow would do — or the reverse.

## Do not report

Formatting, naming taste, missing ApexDoc, anything Code Analyzer, the deploy validation or
`scripts/ci/risk-scan.sh` already gates.

## Format

One comment. Each finding: severity (Blocker / Major / Minor), `file:line`, what is wrong, the change
required. No findings: say so in one line.
