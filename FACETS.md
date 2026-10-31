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
| 26 | Terminal-status split net (work#1029): a gate red bounced over an EXPLICIT conditional edge lands succeeded in the platform record with the publish path running (run PR exists); the catch-all twin (the pre-fix lane-graph shape, run 01M5ZEWKAMMZ) lands failed/workflow_error with NO PR — engine conclusion, terminal event, and record asserted to agree in both directions (user bench directive 2026-10-28) | probe-26-gate-bounce + probe-26-gate-bounce-catchall | fixed: record succeeded AND terminal event succeeded AND run PR exists; catch-all: reason workflow_error AND terminal event succeeded AND zero run PRs | first run 2026-10-28 (this row lands with the probes) |
| 27 | ADR-0019 property pin: the toolchain run sandbox carries NO gh binary — the composition basis the fail-open arms in dup-run-check/prompt-lint ride on (work#1030 class); a flip forces the conscious decision and updates those arms' premises | probe-27-gh-absent | stage red iff `command -v gh` resolves in the sandbox | first green 2026-10-28 (detection branch proven on a gh-ful host) |
| 28 | The closeout work-create argv parses against the TOOLCHAIN's fabro CLI (the fabro-repo smoke only sees the host CLI; run 01M60NX9W7N6 lost a deferred-action filing to a clap reject of exactly this shape — work cf. fabro 34998d5bc) | probe-28-work-create-argv | dead-server call with the exact argv: stderr must NOT contain 'unexpected argument' (transport refusal is the pass shape) | first green 2026-10-28 (clap-reject branch proven with the pre-fix argv on the host) |
| 29 | The gate env-scrub idiom (work#1054): the engine injects FABRO_SERVER via the channel mount (asserted as the precondition) and `env -u` neutralizes it — the form qualitygate.nu's cargo-env helper applies to every cargo tier, composing with PR #500's test-level scrubs so future unscrubbed tests inherit a clean gate env | probe-29-gate-env-scrub | stage red iff FABRO_SERVER is NOT injected (precondition changed) or env -u fails to scrub | first run 2026-10-29 (this row lands with the probe) |
| 30 | The restored 3-reds human guard (work#1057, fabro-6baf regression): the tester's gate-red bounce carries `outcome=failed && nodes.tester.generation < 2` (cap 2 — measured: the breaker loop_restart_signature_limit=3 cuts a `< 3` cap's third loop signature workflow_error first), so the third red matches no conditional edge and lands the run on the unconditional x.kind=deadlock fallback, its SOLE route to exit (fabro-843d) | probe-30-three-reds | run FAILED with reason=deadlock — never workflow_error (breaker), never succeeded (plain gate-green exit beside the kind edge) | first green 2026-10-29 (third drive: 01M637N5BRAHXC87E9RA35BMJ1 reason=deadlock; discriminated drives 01M636T77HA3QSKK4F6G93AQFV workflow_error, 01M63706VG9110QPCB8PB4TJXS succeeded) |
| 31 | The in-sandbox work CLI over the run channel (work#1073, born from the 2026-10-30 loop lap that caught the fork.26/fork.27 toolchain skew): every link of the evidence.nu call shape — env token + FABRO_SERVER, the socket file in the sandbox fs (the compose bind), the handshake enforcement (403 bare / 200 with the owning run's token), and the CLI round trip | probe-31-channel-cli | stage green iff the channel mount, bind, handshake, and scoped CLI all hold | first green 2026-10-30 (row backfilled 2026-10-31 — the probe landed via PR #106/#107 without its FACETS row) |
| 32 | The observation recorder end to end (ADR-0038 stage 1, denkhaus/work#1082): a granted stage calls `fabro_observation_record`, the platform appends the `observation.recorded` record, and ALL THREE surfaces hold — the pebble ToolCallCompleted and the record with the exact category and text on the run's stream, and the live projection folding the entry onto the recorder stage's `observations` | probe-32-observation-record | run SUCCEEDED + stream carries the tool call AND the record (category note, pinned text) + the stage view's observations[0] matches | first run 2026-10-31 (lands with the probe) |
| 33 | The observation presence contract (ADR-0038 stage 1): a stage under `x.observations="required"` with the tool granted that never calls it is INVALID — the engine fails it bad_output with a reason naming the tool and the explicit "nothing durable to record" empty entry | probe-33-observation-contract | run FAILED + events carry bad_output, the tool name, and the empty-entry teaching | first run 2026-10-31 (lands with the probe) |
| 34 | The closure-radius close gate (ADR-0038 stage 3, denkhaus/work#1082): a run's own observation record — its (run, seq) identity — linked to an open blocker item refuses the claimed closer item's close (409 naming the blocker and teaching `--force`), and a forced close succeeds with `overriddenRadius` echoing exactly the blocker; the whole chain (claims-history edge, observation identity off the folded stage view, link, gate, force echo) over HTTP. The recorder records a NOTE since stage 4 (the bench-flood guard: the radius chain is category-agnostic, the bench stops producing painpoints) | probe-34-close-gate | run SUCCEEDED + unforced close 409 with the blocker key + forced close 200 with overriddenRadius == [blocker] | first run 2026-10-31 (note flip lands with stage 4) |
| 35 | The mulch cutover reaches the sandbox (work#1070, ADR-0023): the toolchain run sandbox carries the NATIVE `mulch` binary (release-binary install, musl) and NOT the retired `ml` reference binary — the work#1070 cutover's runtime half, paired to the fork.29 toolchain/server pin | probe-35-mulch-binary | run SUCCEEDED + mulch --version prints + `ml` absent in the sandbox | first run 2026-10-31 (lands with the probe; RED until the fork.29 pairing deploys) |
| 36 | The run-end observation filing (ADR-0038 stage 4, denkhaus/work#1082): a terminal run's painpoint observation files a linked covering item through the settings-gated hook (one distillation call + the mechanical filer's dedupe layers); a second identical run LINKS the existing item instead of refiling (change-dedupe), proven by the unlink/relink roundtrip on the (run, seq) identity. The filing gate toggles ON around the two rows only (settings.toml hot-reload, marker-guarded) — the rest of the bench never files | probe-36-filing-file, probe-36-filing-dedupe | file: item citing the run's Basis line within 150s + revision label; dedupe: no second item within 120s + unlink reports the hook's link + item closed after | first run 2026-10-31 (RED until the local stack carries the stage-4 server build) |
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
