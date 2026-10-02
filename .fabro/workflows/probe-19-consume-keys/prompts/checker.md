Your own prompt carries a "## Context" section. Inspect ONLY what it actually shows, then output exactly one JSON object, no prose, no code fence:

- Context key `consume_target` is NOT visible anymore (consumed by the previous stage):
  {"outcome": "succeeded", "preferred_next_label": "Consume ok"}
- Otherwise (the key leaked through):
  {"outcome": "succeeded", "preferred_next_label": "Leaked"}
