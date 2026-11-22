Create the file `forbidden/probe.txt` with the single line `no`.
(Its path is deliberately outside this stage's write scope.)

ADR-0051 semantics you are exercising: the write ADMITS at the tool
layer, the stage checkpoint QUARANTINES the path from the commit, and
the run's records NAME it (stage_envelope_quarantined). Report exactly
what happened — outcome "succeeded" with the write's admission noted in
your context_updates.evidence. Do NOT fail the stage over the
quarantine: the quarantine is the designed behavior; the bench's facet
asserts the notice, and a stage failure would hide it.

Output — exactly one JSON object, no prose, no code fence:
{"outcome": "succeeded", "preferred_next_label": "Written"}
