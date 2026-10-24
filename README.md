# fabro-test — LLM test line for Fabro workflows

Purpose: test facets of the Fabro cutover line LOCALLY (Docker sandbox)
against a real mini repo and real (cheap) LLM tasks — before deploying to
mirtuell.net. A run takes a few minutes, not 20+.

## Rules
- One facet per test; one seed per run (one mini task, a few minutes).
- Seeds are mini: one function, one fix, one test case — preferably in
  `src/` + `tests/` without a build toolchain (python3-stdlib only).
- Model: zai glm-4.7 (non-reasoning, cheap). No reasoning_effort needed.
- Tracker: `.seeds/issues.jsonl` (git-native, JSONL). Prefix `fabro-test-`.
- All written artifacts are in English (user directive 2026-10-24).

## Workflow `mini` (slim port of develop)
tracker_guard -> planner -> claim_check -> implementer -> tester ->
evidence -> reviewer -> closeout -> exit, with cycle guards
(`nodes.<stage>.generation >= 3` -> deadlock exit).

Tested facets:
1. `Contract::Schema` context_updates spread (planner file schema)
   -> `stdin_source` consumer (claim_check/closeout)   [c5a0 seam]
2. Broad-write envelope: implementer fs_write UNSET, fs_hide narrowed
3. Read-only reviewer: tools allowlist + fs_write=""
4. Command stages with stdin_source + output_schema="routing"
5. Gate (python3 unittest), evidence (git diff), cycle guards
6. PR pipeline: run branch push, squash merge, auto-merge, PR title model

## Work-line probes (fabro-6041, no seeds)
The work-item line (central tracker denkhaus/work, project `fabro-proof`)
has its own probes: `probe-23-work-claim-release` (grant + release
roundtrip) and `probe-24-tool-error-wrap` (error-flag rendering on the
deployed profile path — red until the c98c fix). The workbench maintains
the proof items (canonical `proof-ensure`) and refuses non-local
`FABRO_SERVER` values.

## Local run
```sh
# 1. Server (once):     fabro server start
# single probe:         just probe probe-06-guards   # one facet, no full bench
# 2. Run:               nu scripts/run-mini.nu [--goal 'implement fabro-test-xxxx']
fabro create mini --environment test-local --json --server http://127.0.0.1:32276
fabro start  <run_id> --server http://127.0.0.1:32276
fabro wait   <run_id> --json --server http://127.0.0.1:32276
```
Env: `ZAI_API_KEY` (LLM), `GITHUB_TOKEN` (forge: clone/push/PR).

## Creating seeds
One line per seed in `.seeds/issues.jsonl`:
`{"id":"fabro-test-0001","title":"...","status":"open","type":"task",
  "priority":1,"createdAt":"...","updatedAt":"...","description":"..."}`
