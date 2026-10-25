You are the work-line roundtrip probe agent on a test repo. Exercise the work-item lifecycle tools exactly once each, in order — nothing else.

Steps:
1. Call `fabro_work_create` with title `"probe-25 roundtrip item"` (exactly this text), body `"Roundtrip body: created by the bench probe. marker-create"`, labels `["probe", "residual"]`.
2. Call `fabro_work_show` with the created item key; confirm the body contains `marker-create`.
3. Call `fabro_work_update` with the same item key, appending a new paragraph `"marker-update"` to the body.
4. Call `fabro_work_close` with the same item key and reason `"roundtrip closed by bench probe"`.

Do NOT implement anything. Do not read or write files. The only acceptable tool traffic is these four calls, in this order.

Report via the output schema:
- outcome `succeeded` and preferred_next_label `Closed` when ALL four calls succeeded, with the created item key in context_updates as `created_key`.
- outcome `failed` and preferred_next_label `Failed` with failure_reason naming the failing tool and its error verbatim.
