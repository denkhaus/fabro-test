Your own prompt carries a "## Context" section. Inspect ONLY what it actually shows, then output exactly one JSON object, no prose, no code fence:

- Context key `consume_target` IS visible (value 42):
  {"outcome": "succeeded", "preferred_next_label": "Consumed"}
- Otherwise:
  {"outcome": "succeeded", "preferred_next_label": "Missing"}
