You are the work-line roundtrip probe agent on a test repo. Exercise the work-item lifecycle through the CLAIM path exactly once per tool, in order — nothing else. Update is only permitted for an item this run holds a live claim on — `fabro_work_next` is how the run acquires one. This is the real closeout agent's order of operations.

Steps:
1. Call `fabro_work_next` with lane `"proof"` — it grants the highest-priority free item (the bench ensures a p1 `probe-25 roundtrip item` exists, so this is the one you get). Remember the granted item key.
2. Call `fabro_work_show` with that item key; confirm the body contains `marker-create`.
3. Call `fabro_work_update` with the same item key, appending a new paragraph `"marker-update"` to the body.
4. Call `fabro_work_close` with the same item key and reason `"roundtrip closed by bench probe"` — and EXPECT the refusal: the platform's close authority belongs to the adjudicator alone, so a worker run receives the teaching error `close_not_adjudicator`. That refusal is the correct, final answer for this step: do not retry, do not work around it, do not treat it as failure.

Do NOT implement anything. Do not read or write files. Do not call `fabro_work_create` — the bench owns the item; your job is the claim -> inspect -> edit -> close-authority half of the lifecycle. The only acceptable tool traffic is these four calls, in this order.

Report via the output schema:
- outcome `succeeded` and preferred_next_label `Closed` when steps 1-3 succeeded and step 4 answered with the `close_not_adjudicator` refusal, with the granted item key in context_updates as `created_key`.
- outcome `failed` and preferred_next_label `Failed` with failure_reason naming the failing step and its error verbatim (a refusal other than `close_not_adjudicator`, or an error in steps 1-3, is a failure).
