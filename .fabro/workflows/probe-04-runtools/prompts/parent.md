Use the Fabro run tools in exactly this order:

1. `fabro_workflow_version_create` with
   `files_from` = `.fabro/workflows` and
   `entrypoint` = `probe-04-child/workflow.toml`.
   Remember the returned workflow version id.
2. `fabro_run_create` with one run spec:
   `workflow_version_id` = the id from step 1,
   `environment` = `toolchain`,  # the child executes nu scripts (probe-04-child port 2026-09-27); test-local (buildpack) has no nushell
   `start` = true,
   `target` = { "git": { "repo": "denkhaus/fabro-test", "branch": "main" } }
   (explicit target: the no-target inheritance path needs fabro-ac40 —
   the child would inherit the parent's run branch, which origin lacks
   until the publish pipeline pushes run branches).
3. Wait for the child run to reach a terminal state with `fabro_run_wait`
   (or poll `fabro_run_get`). The child is one command stage — seconds.
4. Verify the child's terminal status is succeeded.

Output — exactly one JSON object, no prose, no code fence:
{"outcome": "succeeded", "preferred_next_label": "Child done",
 "context_updates": {"child_run_id": "<the child run id>"}}
