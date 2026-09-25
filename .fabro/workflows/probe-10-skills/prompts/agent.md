Produce the one-line status text for this bench probe, formatted
according to the loaded bench-style skill (its marker rule applies).

Output — exactly one JSON object, no prose, no code fence:
{"outcome": "succeeded", "preferred_next_label": "Done",
 "context_updates": {"skill_marker": "<the FULL text you produced, marker line included>"}}
