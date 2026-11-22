# Request — top-tier customers stuck on Low priority

From: Lee (team lead, EMEA), Slack #support-ops. Forwarded by Priya (Salesforce admin), unedited.

> Hey, quick one. Two Platinum cases sat in the Low pile all morning yesterday because the web form
> defaults priority to Low and nobody bumped them. Dana was not happy.
>
> Can we make sure our top customers never end up on low priority? Platinum should always be at
> least High. Gold — probably at least Medium, Dana said fine. Normal customers stay as they are.
>
> Also if someone drops a Platinum case to Low later by mistake, it shouldn't stay Low.
>
> And agents should see straight away on the case who they're dealing with — something colourful at
> the top so a Platinum case stands out, and maybe say why the priority is what it is.
>
> Keep it small please, we want it this week. Old cases can stay as they are.

Notes for the demo: the request is short on purpose. The architect should settle from the repo,
without asking, where the tier lives (`Customer_Tier__c`, defaulted to Standard by
`CaseTriggerHandler`) and where the mapping goes (custom metadata, per `CLAUDE.md`). What only Lee
can answer becomes an open question at Gate A — see the gate answer key in
[walkthrough.md](walkthrough.md#gate-answer-key).
