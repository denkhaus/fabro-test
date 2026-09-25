Use the Fabro run tools:
1. `fabro_run_create` a run of the workflow `probe-04-child` with
   environment `test-local`.
2. Wait for that child run to reach a terminal state using
   `fabro_run_wait` (or poll `fabro_run_get`). The child is one command
   stage — it succeeds in seconds.
3. Verify the child's terminal status is succeeded.

Output — exactly one JSON object, no prose, no code fence:
{"outcome": "succeeded", "preferred_next_label": "Child done",
 "context_updates": {"child_run_id": "<the child run id>"}}
