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
| 24 | Tool-result error-flag rendering on the deployed profile path zai->OpenAi (c98c; fabro-6041 N3) | probe-24-tool-error-wrap | >= 2 forced invalid_arguments AND 0 unsupported_control warnings in the events | RED until the real fix (production evidence fork.24 2026-10-24: 4x warning on the live planner) — blocks fork.25 |

Maintenance: new product bugs (rootprint error patterns from mirtuell) land
as a row here + probe + fabro seed, BEFORE any deploy runs.

Bench mandate (user principle 2026-10-24, fabro-6041): the bench is a
living regression net, not an archive. Tests are not set in stone: when an
aspect becomes irrelevant, its row falls. Relevant coverage from the same
context is rescued FIRST (moved or rebuilt). Goal state: fabro-test puts
EVERY aspect of fabro to the test — this table is the coverage map, red
means regression.

Publish note: facet 09 uses the bridge (snapshot push + gh fallback) until
fabro-ac40 (engine publish) replaces it.
