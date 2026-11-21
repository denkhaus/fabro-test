# Issue tracker: bench seeds + central proof items

This repo's issues live in two places, each with its own CLI. Both CLIs
are pinned via mise in `.mise.toml` (same pins as `../fabro`); neither
relies on a global install.

## 1. The bench seed tracker (`.seeds/issues.jsonl`, git-tracked)

The seed items that drive runs live in `.seeds/issues.jsonl`, tracked in
git. ALL mutations go through the `seeds` CLI — never manual JSON edits:

- `mise exec -- seeds list --status open --format ids`
- `mise exec -- seeds show fabro-test-9001 --format json`
- `mise exec -- seeds close <id> --reason "…"`

The canonical seed `fabro-test-9001` ("Implement canonical_mark in
bench/canonical.nu") is a fixed row: `seed-ensure` in
`scripts/workbench.nu` re-pins it idempotently and restores it from git
history when lost — `seeds create` cannot mint it. Bench seeds are
fixtures, never filed by hand.

## 2. The central work-item tracker (proof items)

Facet proof items live on the central tracker: project `fabro-proof` on
`denkhaus/work`, driven by the `fabro work` CLI (the facade ships with
`just up` in `../fabro` / the toolchain image). The bench hygiene rule
applies: always pass `--server https://mirtuell.net` explicitly — never
rely on `FABRO_SERVER`.

- Proof items are maintained by `proof-ensure` at bench time (see
  `scripts/workbench.nu`); item keys are `denkhaus/work#N`; the label
  standard is ADR-0032's (`prio:pN`, `type:*`, lane labels).
- Create: `echo "$body" | fabro work --server https://mirtuell.net
  create --project fabro-proof --title "…" --body-file -`. Bodies NEVER
  travel on a command line — `--body-file -` reads stdin.
- Close: `fabro work --server … close --project fabro-proof <key>
  --reason "<evidence>"` — `--reason` is required and carries the
  evidence (run ids, FACETS row, PR url).

## When a skill says "publish to the issue tracker"

Create a proof/demand item on the central tracker with the stdin form
above: context, acceptance criteria, and evidence links in the body.

## When a skill says "fetch the relevant ticket"

`fabro work --server … show --project fabro-proof <key|number>` for
proof items; `mise exec -- seeds show <id>` for bench seeds.
