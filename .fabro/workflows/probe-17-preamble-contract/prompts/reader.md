Your own prompt carries a "## Context" section and (possibly) completed-stage output blocks. Inspect ONLY what your own prompt actually shows. Then output exactly one JSON object, no prose, no code fence — pick the label by this table:

- You CAN see context key `contract_kept` (value visible-value),
  AND you CANNOT see context key `contract_hidden`,
  AND you CANNOT see any output block of the completed stage `noisy`:
  {"outcome": "succeeded", "preferred_next_label": "Contract ok"}
- Otherwise (hidden key leaked, kept key filtered away, or the noisy stage's output block is visible):
  {"outcome": "succeeded", "preferred_next_label": "Leaked"}
