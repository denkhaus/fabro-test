# retry-fix-lab — checkpoint journal

Instrument for the fork/retry-on-new-tip semantics test (user session
2026-11-14). Each agent work stage appends its entry here; the engine
checkpoints the result onto the run branch. Presence vs absence of a
source entry on a replayed run's branch is the carry-vs-fresh
read-out.

Provenance: entry 1 (run `01M7CQG5NM79NS8EWVRYQKBKDP`, branch
`fabro/run/01M7CQG5NM79NS8EWVRYQKBKDP`) is NOT on this branch — the
run branches diverge at the specimen commit `66bd39`. This branch is
the first to carry the journal to main (this run's publish PR lands
it), so fresh runs append after entry 2.

## Entry 2 — agent work stage (lap 3, the fix lap)

- Run: `01M7CQZ2D5C3K9JF1ZBMPWPFRP`
- Branch: `fabro/run/01M7CQZ2D5C3K9JF1ZBMPWPFRP`, base `66bd39`
  (`retry-fix-lab-specimen (#164)`, the main tip at fire time), start
  commit `fbf7bff`
- Stage: `work` (LLM agent, prompt "make real changes")
- Written: 2026-11-14T10:09:06Z

### The checkpoint work

1. This journal entry.
2. THE SPECIMEN FIX (the lap-2 root cause): the pinned graph gave
   `work` and `check` BOX shapes with dead `script=` attributes, so
   the engine ran both as LLM agents (`inspect`: `handler=agent`).
   The red script never failed a stage — lap 2's check agent ran
   `nu scripts/check.nu`, reported the red, completed its turn, and
   the run reached exit SUCCEEDED. No blocked specimen ever existed.
   This branch fixes the graph: `check` becomes a parallelogram
   SCRIPT stage (`nu scripts/check.nu`, `max_retries=0`,
   `on_failure="exit"` — the work#1277 attribute, probe-44 facet) so
   the fault actually blocks the run AT check; the dead `script=`
   attributes are removed; `work` stays the agent stage (the
   checkpoint-work maker). It lands on main via this run's publish
   PR. Admission re-validated: `Validation: OK`, with the engine
   itself confirming the shape semantics (warning: agent node `work`
   — its label is the prompt).
3. The `check.nu` comment corrected: the fault is a PARSE-time type
   error (`nu::parser::operator_incompatible_types`, nu 0.116.1), not
   runtime as claimed — lap 2's Randbeobachtung, now fixed at the
   source. The fault line `let fault = (1 + "fault")` is untouched
   (byte-identical; verified: exit 1 after the edit).

### Lap-2 falsification (recorded against entry 1)

- Entry 1, prediction 2 FALSIFIED: the pinned graph's work stage is
  agent-shaped, so a fork/retry replays an AGENT work stage, never
  the bare scripted append. The stage table's handler column, not the
  file image, is the discriminator.
- Entry 1, predictions 1/5 held only vacuously: the run never
  blocked, so the blocked state they describe never existed.

### Pre-registered predictions (recorded BEFORE any fork/retry)

P1 Pinned-version replay (ADR-0008): a fork/retry of THIS run replays
   THIS run's version (base `66bd39`) — its stage table shows
   `check@1` with `handler=agent`, although post-publish main carries
   the parallelogram script check. The handler column is the pin
   proof.
P2 The replay's check agent again sees `nu scripts/check.nu` fail
   (parse-time type error) — a main-side fix never reaches it.
P3 The replay still ends SUCCEEDED (an agent stage cannot fail the
   run): for forks of THIS lap, "still red" reads at stage level,
   never at run level.
P4 Fresh run on post-publish main: start -> work (agent) -> check
   (parallelogram, faulty) -> run FAILED AT check: status failed,
   stage table has a check row and NO exit row (the probe-44 shape),
   with checkpoint commits for start+work carrying that run's journal
   entry. This is the intended blocked specimen.
P5 Carry-vs-fresh: a fork/retry branch carries its source run's
   checkpoint commits (the `fabro(<run-id>): <stage> (success)`
   commits — verify with `git log` on the new run branch); a
   fresh-start-on-new-tip fork has only the new main tip plus its own
   commits, and the source entry is absent from its `RETRY-LAB.md`.
P6 Fix leg: after a `check.nu` fault fix lands on main, fresh runs go
   green (`check` -> `exit`); forks of pre-fix-pinned runs keep the
   fault. The two never flip together.

### How to read the outcome

- `fabro inspect <run-id> --json` -> `stages`: `handler` + `state`
  per stage (P1/P3/P4), plus the terminal status/reason.
- `git log` and the `RETRY-LAB.md` diff between the source and replay
  run branches (P5).
- `start_record.base_sha` of the replay — old base vs the moved main
  tip IS the "on-new-tip" question itself.
