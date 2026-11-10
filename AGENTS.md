# AGENTS.md — fabro-test conventions

## Written language: English (ADR-0033 in ../fabro)

Chat replies in German; every written artifact in this repo is English —
docs, catalogs (FACETS.md), comments, commit messages, PR bodies. A
German file does not license German additions: translate the whole file
in one change, never leave a mixed-language file. Sole exemption: test
data that deliberately exercises non-English model output (the
mimo-flash prompt), and it is named as such.

## The bench

- `FACETS.md` is the coverage map: one row per facet, red means
  regression. Its rules block carries the budget and the bench mandate
  (living regression net — rows follow aspects, relevant coverage is
  rescued before a row falls).
- `just up` in ../fabro refreshes image + CLI; `just workbench` runs the
  full bench. Red table = no deploy window.
- Work-line facets run WITHOUT seeds against the central tracker
  (project `fabro-proof` on denkhaus/work); proof items are maintained
  by `proof-ensure` at bench time.
- The bench refuses a non-local `FABRO_SERVER` unless
  `FABRO_BENCH_ALLOW_REMOTE=1`.

## Landing

`nu scripts/land.nu '<subject>'` — branches `bench/workbench`, stages
scripts/, justfile, .fabro/workflows, FACETS.md, README.md, AGENTS.md,
opens or reuses the PR, waits for checks, squash-merges with --admin,
resyncs main.

## Probe staleness on contract changes

Every change to a door's or authority's semantics (who may close, who
may write, what a refusal means) MUST review the probes that assert
the OLD contract — a green bench proves the probes, not the platform
(probe-25 asserted the retired pre-ADR-0039 worker self-close for five
days, 2026-11-03..10, reading the platform's correct teaching refusal
as red). When a door changes, grep the probes for its tool names and
re-decide each expectation in the same change.
