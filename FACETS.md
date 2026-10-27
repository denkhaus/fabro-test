# fabro-test Workbench — Facet Catalog

Purpose: after every upstream merge (`just up` in the fabro repo refreshes
image + CLI), `just workbench` runs here: minimal workflows test every
facet, locally in Docker, glm-4.7. Green -> deploy to mirtuell. Red ->
seed/fix BEFORE the deploy.

Rules: 1 facet = 1 probe workflow, <= 3 stages, stage timeouts, sandbox
scripts in python3 (the env image buildpack-deps:noble has no nu), host
scripts in nu. Budget: < 15 min and < 1 EUR per workbench run. All written
artifacts are in English (user directive 2026-10-24: no language jumble).

| # | Facet | Probe | Expectation | Evidence |
|---|-------|-------|-------------|----------|
| 01 | Contract::Schema context_updates spread (c5a0) | probe-01-schema | the stdin consumer reads the schema value | run 5/6 (session 2026-09-25) |
| 02 | Narrow write envelope (fs_write pin + deny) | probe-02-envelope | allowed file present, forbidden file absent | new |
| 03 | Tools allowlist (read-only agent) | probe-03-tools | read task succeeds, write attempt denied | new |
| 04 | Run tools: fabro_run_create + wait (child run) | probe-04-runtools | child run created + succeeded | new |
| 05 | Sandbox hooks (stage_complete) | probe-05-hooks | journal entry in the run workspace | new |
| 06 | Cycle guards (generation >= 3 -> deadlock) | probe-06-guards | run terminates as deadlock, not an endless loop | new |
| 07 | Artifacts ([run.artifacts] include) | probe-07-artifacts | artifact.collected record in the run events | new |
| 08 | HITL/interview: all 5 question types (yes_no, confirmation, multiple_choice, multi_select, freeform) | probe-08-interview | every question answered via API, run green | fabro-dbb4 (model) |
| 09a | Full seeds loop (mini + publish bridge) | mini | seed implemented, PR squash-merged, tracker closed | PRs #1/#2 |
| 09b | Write envelope refuses outside the scope (stage fails hard) | probe-09-envelope-deny | run failed with 'envelope violation' | run 01M3D4FAS6WX0M |
| P1 | Server API: health/models/environments | workbench (nu) | 200 + zai configured + env registry | smoke |
| P2 | Web: SPA index + asset | workbench (nu) | index references asset | smoke |
| P3 | Completions smoke (real LLM call) | workbench (nu) | 1-token answer | open (to build) |
| 10 | Skill calling ([run.agent] skills + UseSkill) | probe-10-skills | marker from a loaded skill | new |
| 11 | Parallel fan-out/join (2 edges + join node) | planned | wall time < sum, join sees both markers | open |
| 06 | Generation guards (fabro-51ad landed 2026-09-26: condition lowering, exit-kind mapping, breaker option a) | probe-06-guards | deadlock exit under the DEFAULT limit | bench 0926-112218 + 0926-112401 |
| 11 | Admission refuses unknown x.* (fabro-70af root) | probe-11-admission-deny | the create refusal names fork.x_attribute_known | new |
| 12 | The conditional success edge beats the unconditional soft-exit edge (tiering) | probe-12-tier-shape | run succeeded (not SoftStop) | bench=single-0926-135441 |
| 03 | x.tools allowlist (fabro-1a41 landed 2026-09-26: ToolPolicyHooks, engine-layer denial) | probe-03-tools | write_file denied, run succeeded | bench=single-0926-112254 |
| 23 | Work-item line entirely without seeds: fabro_work_next grant + fabro_work_release against project fabro-proof on the CENTRAL tracker denkhaus/work (fabro-6041) | probe-23-work-claim-release | run succeeded AND work.claimed + work.released in the run events | new (proof items denkhaus/work#3/#4, canonical proof-ensure) |
| 24 | Tool-result error-flag rendering on the deployed profile path zai->OpenAi (c98c; fabro-6041 N3) | probe-24-tool-error-wrap | >= 2 is_error ToolCallCompleted events AND 0 unsupported_control Warning events | GREEN 2026-10-24 (pebble 47a036fd, probe run 01M5Q5TMJ8: marker replaces the flag, agent quoted [TOOL ERROR]) |
| 25 | Work-item lifecycle roundtrip on a CLAIMED item: next (claim) -> show -> update -> close through the run tools (fabro-6041 user direction 2026-10-25; rescued 2026-10-27 for the claim-binding core denkhaus/work#991 — update/close are claim-bound by design, the pre-#991 create-first contract went red by design; the bench files a p1 `probe-25 roundtrip item` target before the run) | probe-25-work-roundtrip | 4 successful ToolCallCompleted events (one per tool) AND the newest closed item titled 'probe-25 roundtrip item' on denkhaus/work carries marker-create + marker-update | first green 2026-10-27 bench=1027-162117 (target denkhaus/work#1027; fork.26 image 0a7077ff2f78) |
| P4 | CLI facade over work items: `fabro work list/show/create/close/claims` on the bench's own `cli-test` items (cutover stage 1b, fabro-cc1b; the host scripts leave `.seeds` behind) | work-cli-checks (nu) | 3 rows green: the created item appears in the open list, `show` by BARE NUMBER prints the body that only travelled through stdin, `close` reports it, `claims` reads the queue | first green 2026-10-25 (denkhaus/work#15) |

Maintenance: new product bugs (rootprint error patterns from mirtuell) land
as a row here + probe + fabro seed, BEFORE any deploy runs.

Bench note (P4 work CLI): the row exercises the `fabro` BINARY, not the
server, so it needs a binary that carries the `work` verb. It resolves
`FABRO_BIN` first and falls back to `~/.fabro/bin/fabro` (run-mini
precedent) — a stale install reports itself in the row detail instead of
blaming the server. GitHub's label-filtered list converges a few seconds
after a write (measured on denkhaus/work#10..#12: create, then the list
missed the item for ~2s), so the row polls up to 6 times at 2s instead of
asserting the index's mood.

Bench mandate (user principle 2026-10-24, fabro-6041): the bench is a
living regression net, not an archive. Tests are not set in stone: when an
aspect becomes irrelevant, its row falls. Relevant coverage from the same
context is rescued FIRST (moved or rebuilt). Goal state: fabro-test puts
EVERY aspect of fabro to the test — this table is the coverage map, red
means regression.

Publish note: facet 09 uses the bridge (snapshot push + gh fallback) until
fabro-ac40 (engine publish) replaces it.
