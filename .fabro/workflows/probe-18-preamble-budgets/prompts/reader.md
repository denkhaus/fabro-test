Your own prompt carries the completed stage `noisy` with its output block, capped by the engine. Inspect ONLY what your own prompt actually shows, then output exactly one JSON object, no prose, no code fence:

- The early marker `FILLER-LINE-01` IS visible AND the late markers `FILLER-LINE-06` and beyond are NOT visible (truncated by the cap):
  {"outcome": "succeeded", "preferred_next_label": "Budget ok"}
- Otherwise:
  {"outcome": "succeeded", "preferred_next_label": "Uncapped"}
