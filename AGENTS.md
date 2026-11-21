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

## Agent skills

### Issue tracker

Two trackers, both CLIs pinned via mise (same pins as `../fabro`): bench
seeds in `.seeds/` via the `seeds` CLI; proof items on the central
tracker (project `fabro-proof` on denkhaus/work) via the `fabro work`
CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage role labels, used as-is. See
`docs/agents/triage-labels.md`.

### Domain docs

Single-context: local `GLOSSARY.md` + `docs/adr/` are created lazily;
the governing platform glossary and ADRs live in `../fabro`. See
`docs/agents/domain.md`.

<!-- mulch:start -->
## Project Expertise (Mulch)
<!-- mulch-onboard:v0.1.0 -->

This project uses [Mulch](https://github.com/jayminwest/mulch) v0.1.0 for structured expertise management.

**At the start of every session**, run:
```bash
mulch prime
```

Injects project-specific conventions, patterns, decisions, failures, references, and guides into
your context. Run `mulch prime --files src/foo.ts` before editing a file to load only records
relevant to that path (per-file framing, classification age, and confirmation scores included).

For monolith projects where dumping every record wastes context, set
`prime.default_mode: manifest` in `.mulch/mulch.config.yaml` (or pass `--manifest`) to emit a
quick reference + domain index. Agents then scope-load with `mulch prime <domain>` or
`mulch prime --files <path>`.

**Before completing your task**, record insights worth preserving — conventions discovered,
patterns applied, failures encountered, or decisions made:
```bash
mulch record <domain> --type <convention|pattern|failure|decision|reference|guide> --description "..."
```

Evidence auto-populates from git (current commit + changed files). Link explicitly with
`--evidence-seeds <id>` / `--evidence-gh <id>` / `--evidence-linear <id>` / `--evidence-bead <id>`,
`--evidence-commit <sha>`, or `--relates-to <mx-id>`. Upserts of named records merge outcomes
instead of replacing them; validation failures print a copy-paste retry hint with missing fields
pre-filled.

Run `mulch status` for domain health, `mulch doctor` to check record integrity (add `--fix` to strip
broken file anchors), `mulch --help` for the full command list. Write commands use file locking and
atomic writes, so multiple agents can record concurrently. Expertise survives `git worktree`
cleanup — `.mulch/` resolves to the main repo.

`mulch prune` soft-archives stale records to `.mulch/archive/` instead of deleting them; pass
`--hard` for true deletion. Restore an archived record with `mulch restore <id>`. Do not read
`.mulch/archive/` directly — those records are stale by definition. If you need historical
context, run `mulch search --archived <query>`.

### Before You Finish

If you discovered conventions, patterns, decisions, or failures worth preserving during
this session, record them before closing:

```bash
mulch learn                                                                    # see what files changed
mulch record <domain> --type <convention|pattern|failure|decision|reference|guide> --description "..."
mulch sync                                                                     # validate, stage, commit
```

Skip if no insight surfaced. Unrecorded learnings are lost; ritual filler records are also noise.
<!-- mulch:end -->
