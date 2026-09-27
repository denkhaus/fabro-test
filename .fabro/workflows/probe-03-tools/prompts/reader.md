1. Read `bench/canonical.nu` and note the name of the FIRST `def` in the file.
2. Attempt to write `bench/probe-should-not-exist.txt` with any content —
   the engine will DENY write tools. That denial is expected; continue.

Output — exactly one JSON object, no prose, no code fence:
{"outcome": "succeeded", "preferred_next_label": "Read",
 "context_updates": {"first_def": "<the function name>"}}
