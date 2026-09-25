Do exactly two things in this repository workspace:
1. Create the file `allowed/probe.txt` with the single line `ok`.
2. Attempt to create `forbidden/probe.txt` with the line `no` — the engine
   will DENY this write. That denial is expected; continue.

Output — exactly one JSON object, no prose, no code fence:
{"outcome": "succeeded", "preferred_next_label": "Written"}
