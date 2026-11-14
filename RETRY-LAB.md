# retry-fix-lab — checkpoint journal

Instrument for the fork/retry-on-new-tip semantics test (user session
2026-11-14). Each work stage appends its entry here; the engine
checkpoints the result onto the run branch. The file doubles as the
version discriminator: the PINNED scripted work stage appends a bare
`retry-fix-lab work stage at <timestamp>` line, an agent work stage
writes a full entry — a fork/retry that replays the pinned version is
visible in this file at a glance.

## Entry 1 — agent work stage

- Run: `01M7CQG5NM79NS8EWVRYQKBKDP` (execution 0, firing 1, attempt 1)
- Branch: `fabro/run/01M7CQG5NM79NS8EWVRYQKBKDP`, base `7872902`
  (start commit, main tip `66bbd39 retry-fix-lab-specimen (#164)`)
- Stage: `work` (LLM agent, prompt "make real changes")
- Written: 2026-11-14T09:53:50Z

### The checkpoint work

This journal entry is the checkpoint content. The run's next stage
(`check`) runs `.fabro/workflows/retry-fix-lab/scripts/check.nu`, which
fails at runtime by design (`1 + "fault"`) and blocks the run — the
blocked state with this checkpoint present is the specimen under test.

### Pre-registered predictions (recorded BEFORE any fork/retry)

Pinned-version replay (ADR-0008: graph + prompts + scripts are one
unit, pinned at run creation):

1. A fix to `scripts/check.nu` merged to main AFTER this run was
   created does NOT unblock it: a retry or fork replays the pinned
   workflow version and fails at `check` again with the same runtime
   type error.
2. A fork/retry that replays the pinned SCRIPTED work stage appends a
   bare `retry-fix-lab work stage at <timestamp>` line below this
   entry — it never re-runs this agent stage.

Checkpoint-work semantics on a new main tip:

3. If the fork/retry rebases or carries the run-branch commits onto
   the new main tip, this journal entry survives the carry (verify:
   the new run's branch contains this file's entry 1).
4. If the fork/retry starts a fresh workspace from the new tip, this
   entry is ABSENT there (verify: the new run's branch has no entry 1
   and no prior checkpoint commits).
5. Either way the new run terminates at `check` while the fault is
   unfixed on its replayed workflow version — success of the carry
   (3 vs 4) is decided SOLELY by this file's presence, never by the
   run's outcome.

### How to read the outcome

After forking/retrying the blocked run: diff the new run's branch
against this one for `RETRY-LAB.md`, and compare the new run's `check`
failure reason against this run's. Predictions 1 and 5 must hold for
the pinned-version contract; predictions 3 vs 4 decide the
carry-vs-fresh question the session is asking.
