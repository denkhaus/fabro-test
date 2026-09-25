Use the Fabro run tools in exactly this order:

1. `fabro_workflow_version_create` with
   `files_from` = `.fabro/workflows` and
   `entrypoint` = `probe-04-child/workflow.toml`.
   Remember the returned workflow version id.
2. `fabro_run_create` with one run spec:
   `workflow_version_id` = the id from step 1,
   `environment` = `test-local`,
   `start` = true.
3. Wait for the child run to reach a terminal state with `fabro_run_wait`
   (or poll `fabro_run_get`). The child is one command stage — seconds.
4. Verify the child's terminal status is succeeded.

Output — exactly one JSON object, no prose, no code fence:
{"outcome": "succeeded", "preferred_next_label": "Child done",
 "context_updates": {"child_run_id": "<the child run id>"}}
