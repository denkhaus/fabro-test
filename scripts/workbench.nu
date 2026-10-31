#!/usr/bin/env nu
# THE workbench: pre-clean the board, then all probes + platform checks
# + mini integration with publish. Every run carries label bench=<id>.
# Red/green table per facet; red -> exit 1.

# Runplace-agnostic: the server comes from FABRO_SERVER (same convention
# as run-mini.nu); unset defaults to the local dev stack.
def server []: nothing -> string { $env.FABRO_SERVER? | default 'http://127.0.0.1:32276' }

# Bench safety (fabro-6041 hygiene rule, 2026-10-24 incident): an exported
# FABRO_SERVER pointing at production silently sent a probe run at
# mirtuell. The bench fires runs and mutates the work registry — refuse
# non-local servers unless FABRO_BENCH_ALLOW_REMOTE=1 is set in the same
# breath as an explicit decision.
def assert-local-server []: nothing -> nothing {
    let s = (server)
    let local = ($s | str starts-with 'http://127.0.0.1') or ($s | str starts-with 'http://localhost')
    if (not $local) and ($env.FABRO_BENCH_ALLOW_REMOTE? | default '') != '1' {
        print -e $"workbench: refusing non-local server '($s)' — the bench fires runs and writes the work registry. Set FABRO_BENCH_ALLOW_REMOTE=1 to force."
        exit 2
    }
}
const FABRO = ('~/.fabro/bin/fabro' | path expand)

# Probe registry: default expectation per workflow (probe-06/09 expect failure).
const PROBES = [
    [name expect];
    [probe-01-schema succeeded]
    [probe-02-envelope succeeded]
    [probe-03-tools succeeded]
    [probe-04-runtools succeeded]
    [probe-05-hooks succeeded]
    [probe-06-guards failed]
    [probe-07-artifacts succeeded]
    [probe-08-interview succeeded]
    [probe-09-envelope-deny failed]
    [probe-11-admission-deny refused]
    # fabro-70af residual probes: the preamble family enforced (PART 2b,
    # PR #350 salvage) — green proves the enforcement end to end.
    [probe-17-preamble-contract succeeded]
    [probe-18-preamble-budgets succeeded]
    [probe-19-consume-keys succeeded]
    [probe-20-skill-token succeeded]
    [probe-21-blob-marker succeeded]
    [probe-12-tier-shape succeeded]
    [probe-13-runid succeeded]
    # probe-14: known-red until the petri full-history checkout hardening
    # (fabro-df60 option a, petri 603e40e, 2026-09-28); green since.
    [probe-14-shallow succeeded]
    # probe-15: two path-like /tokens in a stage prompt must not kill the
    # agent session (fabro-3fce: pebble's skill expansion fired on
    # harness-assembled input; a red probe-15 means the class is back).
    [probe-15-skills-two-tokens succeeded]
    # probe-16: a sandbox=false hook must read FABRO_HOOK_CONTEXT with a
    # non-empty run id (petri 5bdb90c, fabro-b714). The workbench also
    # checks the run's hook notes for a failed host hook.
    [probe-16-hosthook succeeded]
    # probe-22: diagnostic capture (fabro-114c) — the run sandbox's full
    # env, effective git config, ambient scratch-commit identity, and the
    # run branch's checkpoint identities, echoed into the run log.
    [probe-22-sandbox-env succeeded]
    # Work-line probes (fabro-6041): the central tracker denkhaus/work,
    # project fabro-proof, NO seeds anywhere in the path.
    [probe-23-work-claim-release succeeded]
    # probe-24: the c98c regression net. GREEN since 2026-10-24 (pebble
    # 47a036fd — the marker replaces the flag; probe run 01M5Q5TMJ8:
    # two is_error tool results, zero unsupported_control warnings, the
    # agent quoted the [TOOL ERROR] markers).
    [probe-24-tool-error-wrap succeeded]
    # probe-25: the work-item lifecycle roundtrip (fabro-6041 user
    # direction 2026-10-25) — create -> show -> update -> close, the
    # closeout agent's exact tool set (fabro-9986's first productive
    # dependency, deterministically green before any lap relies on it).
    [probe-25-work-roundtrip succeeded]
    # probe-26 (work#1029, user bench directive 2026-10-28): the
    # terminal-status split net. The fixed shape (explicit conditional
    # bounce) must land succeeded WITH the run PR; the catch-all twin
    # (the pre-fix lane-graph shape) must land failed/workflow_error
    # with NO PR — pinning both directions so any future fold/graph
    # regression reddens the bench.
    [probe-26-gate-bounce succeeded]
    [probe-26-gate-bounce-catchall failed]
    # probe-27/28 (user testing-philosophy directive 2026-10-28: targeted
    # single-aspect probes that compose — real lane graphs deliberately
    # NOT bench material): 27 pins the ADR-0019 property the fail-open
    # arms compose on (gh absent in the toolchain sandbox); 28 pins the
    # closeout work-create argv grammar against the TOOLCHAIN's fabro
    # CLI (the fabro-repo smoke only sees the host CLI — run
    # 01M60NX9W7N6 lost a filing to a clap reject here).
    [probe-27-gh-absent succeeded]
    [probe-28-work-create-argv succeeded]
    # probe-29 (work#1054): the gate env-scrub idiom — the engine injects
    # FABRO_SERVER (channel mount), the gate's cargo tiers must not see it.
    [probe-29-gate-env-scrub succeeded]
    # probe-30 (work#1057, restored fabro-6baf guard): the third
    # consecutive gate red exits to the human as a DEADLOCK — the check
    # arm asserts reason=deadlock, not workflow_error (the breaker
    # cutting an unbounded bounce) and not succeeded (a plain gate-green
    # exit beside the kind edge would leave the finish unclassified).
    [probe-30-three-reds failed]
    # probe-31 (work#1073, born from the 2026-10-30 loop lap): the
    # in-sandbox work CLI over the run channel — the exact evidence.nu
    # call shape. Asserts every link: env token + FABRO_SERVER, the
    # socket file in the sandbox fs (the compose bind), the handshake
    # enforcement (403 bare / 200 with token), and the CLI round trip.
    # The bench gap it closes: probes 23/25 drive the ENGINE work tools;
    # nothing drove the channel CLI until the loop lap caught the
    # fork.26/fork.27 version skew red in production.
    [probe-31-channel-cli succeeded]
    # probe-32 (ADR-0038 stage 1, denkhaus/work#1082): a granted stage
    # records one observation and the entry reaches the run's stream —
    # the tool call (pebble ToolCallCompleted), the platform record
    # (observation.recorded with the exact category and text), both
    # asserted on the events the run left behind.
    [probe-32-observation-record succeeded]
    # probe-33 (ADR-0038 stage 1): a required stage that never calls the
    # recorder is INVALID — the engine's presence contract fails the
    # stage with bad_output and a reason that names the tool and the
    # "nothing durable to record" empty entry, and the run goes red.
    [probe-33-observation-contract failed]
    # probe-34 (ADR-0038 stage 3, denkhaus/work#1082): the closure-radius
    # gate end to end — the run's own observation record (its (run, seq)
    # identity read off the folded stage view) blocks a linked item's
    # close with the 409 listing, and force overrides with the response
    # echoing exactly the overridden item. All HTTP; no binary in the
    # path.
    [probe-34-close-gate succeeded]
]

def auth-header []: nothing -> record {
    # dev-token entries carry `token`; OAuth entries carry `access_token`
    # (short-lived — the CLI refreshes it; run the bench with a fresh login
    # window when raw http calls start failing mid-run).
    let s = (open ~/.fabro/auth.json | get servers | get -o (server))
    let token = ($s | get -o token | default ($s | get -o access_token | default ''))
    { Authorization: $"Bearer ($token)" }
}

def fail [msg: string]: nothing -> nothing {
    print -e $"╔══ WORKBENCH ALARM: ($msg) ══╗"
    exit 1
}

# Kanban hygiene (user directive): the board shows ONLY this bench's runs.
def clean-runs []: nothing -> nothing {
    mut rounds = 0
    loop {
        if $rounds > 10 { break }
        $rounds = ($rounds + 1)
        let ids = (http get --headers (auth-header) $"((server))/api/v1/runs?limit=250" | get -o data | default [] | get id)
        if ($ids | is-empty) { break }
        let body = ({ run_ids: $ids, force: true } | to json -r)
        let _ = (http post --headers (auth-header) -t 'application/json' $"((server))/api/v1/runs/delete" $body)
    }
    print $"== workbench: board cleaned after ($rounds - 1) batches"
}

# Answer every pending HITL question by kind until the run is terminal.
# Question ids carry a fragment-style separator ("yes_no#2") — url-encode
# them or the path silently truncates at the # (404 loop, bench 0927-172546).
# OAuth access tokens live ~10 min: refresh via one CLI call before the
# loop and every 30 polls (external refresher processes are not reliable).
def hitl-answer [run_id: string]: nothing -> bool {
    let _ = (do { ^$FABRO system info --server (server) } | complete)
    mut refreshed = 0
    for _ in 1..300 {
        $refreshed = ($refreshed + 1)
        if ($refreshed // 30) == ($refreshed / 30) {
            let _ = (do { ^$FABRO system info --server (server) } | complete)
        }
        let qs = (http get --headers (auth-header) $"((server))/api/v1/runs/($run_id)/questions" | get -o data | default [])
        let pending = ($qs | where {|q| (($q | get -o status | default 'pending') == 'pending')})
        if ($pending | is-empty) {
            let st = (http get --headers (auth-header) $"((server))/api/v1/runs/($run_id)" | get -o lifecycle | get -o status | get -o kind | default '')
            if $st in ['succeeded' 'failed'] { return true }
            sleep 2sec
            continue
        }
        let q = ($pending | first)
        let qid = ($q | get -o id | default '')
        let kind = ($q | get -o question_type | default '')
        if ($qid | is-empty) { return false }
        let keys = ($q | get -o options | default [] | get key | default [])
        let body = if $kind in ['yes_no' 'confirmation'] {
            '{"kind": "yes"}'
        } else if $kind == 'multiple_choice' {
            if ($keys | is-empty) { '{"kind": "selected", "option_key": "Y"}' } else {
                ({ kind: 'selected', option_key: ($keys | first) } | to json -r)
            }
        } else if $kind == 'multi_select' {
            if ($keys | is-empty) { '{"kind": "multi_selected", "option_keys": ["Y"]}' } else {
                ({ kind: 'multi_selected', option_keys: [($keys | first)] } | to json -r)
            }
        } else {
            '{"kind": "text", "text": "workbench auto-answer"}'
        }
        let _ = (try {
            http post --headers (auth-header) -t 'application/json' $"((server))/api/v1/runs/($run_id)/questions/($qid | url encode)/answer" $body
        } catch { null })
        sleep 1sec
    }
    false
}

def platform-checks []: nothing -> list<record> {
    mut rows = []
    let health = (http get $"((server))/health")
    $rows = ($rows | append {facet: 'P1 health', ok: ($health.status? == 'ok'), detail: ($health | to json -r)})
    let models = (http get --headers (auth-header) $"((server))/api/v1/models?provider=zai&limit=5" | get -o data | default [])
    let glm = ($models | where id == glm-4.7 | first | default null)
    $rows = ($rows | append {facet: 'P1 zai glm-4.7 configured', ok: ($glm != null and ($glm | get -o configured | default false)), detail: ''})
    let envs = (http get --headers (auth-header) $"((server))/api/v1/environments" | get data | get id)
    $rows = ($rows | append {facet: 'P1 env toolchain', ok: ($envs | any {|e| $e == 'toolchain'}), detail: ($envs | str join ',')})
    # The toolchain env MUST inject git's safe.directory: the sandbox
    # workspace arrives uid-mapped (engine-delivered checkout, fabro-b6c5
    # pass 3) while stage scripts exec as root — without the injection
    # every in-sandbox git refuses the repo (dubious ownership) and the
    # git-evidence probes go red (bench 1024-191510, probe-22; production
    # has carried the trio since the same finding).
    let tcenv = (http get --headers (auth-header) $"((server))/api/v1/environments/toolchain" | get -o env | default {})
    let injected = (($tcenv | get -o GIT_CONFIG_KEY_0 | default '') == 'safe.directory') and (($tcenv | get -o GIT_CONFIG_VALUE_0 | default '') == '*') and (($tcenv | get -o GIT_CONFIG_COUNT | default '') == '1')
    $rows = ($rows | append {facet: 'P1 toolchain env injects git safe.directory', ok: $injected, detail: ($tcenv | to json -r)})
    let index = (http get $"((server))/" | str contains '<html')
    $rows = ($rows | append {facet: 'P2 SPA index', ok: $index, detail: ''})

    # Run titles take zai's small default, and that model must be the one
    # the fork declares structured output for (glm-4.7). A red row means
    # every run title falls back to the deterministic goal text
    # (fabro-d5b1: the title path was refused, "model zai/glm-5.3 does not
    # support structured output").
    let small = ($models | where small_default == true | first | default null)
    $rows = ($rows | append {
        facet:  'P1 run-title model is the structured small default'
        ok:     (($small | get -o id | default '') == 'glm-4.7')
        detail: ($"small_default=($small | get -o id | default 'none')")
    })

    # A replace that omits on_overlap must not wipe it: the UI's toggle
    # sends exactly that payload and silently cleared the conductor's skip
    # (fabro-2093). The scratch automation is deleted again either way.
    let scratch = (do {
        # Idempotent: a previous bench (or this one after a failure) may have
        # left the scratch automation behind. The LIST never 404s; a direct
        # GET on a missing id would abort the whole workbench.
        let existing = (http get --headers (auth-header) $"((server))/api/v1/automations" | get data | get id)
        if ('bench-on-overlap-probe' in $existing) {
            let stale = (http get --headers (auth-header) $"((server))/api/v1/automations/bench-on-overlap-probe")
            let stale_headers = ((auth-header) | merge {"If-Match": $"\"($stale.revision)\""})
            let _ = (do -i { http delete --headers $stale_headers $"((server))/api/v1/automations/bench-on-overlap-probe" })
        }
        # work_project names the registered bench project (f1a9: create
        # refuses without one). The REPLACE body below omits it on purpose:
        # a replace keeps the stored binding — the f1a9 pin, proven here.
        let created = (http post --headers (auth-header) -t 'application/json'
            $"((server))/api/v1/automations"
            ({id: 'bench-on-overlap-probe', name: 'bench-on-overlap-probe', environment_id: 'toolchain',
              work_project: 'fabro-proof',
              target: {kind: 'git', repo: 'denkhaus/fabro-test', branch: 'main'}, workflow: 'probe-13-runid',
              triggers: [{type: 'api', id: 'manual', enabled: true}]} | to json -r))
        let rev = ($created | get -o revision | default '')
        let body = ({name: $created.name, environment_id: $created.environment_id, target: $created.target,
                     workflow: $created.workflow, triggers: $created.triggers} | to json -r)
        let put_headers = ((auth-header) | merge {"If-Match": $"\"($rev)\""})
        let _ = (http put --headers $put_headers -t 'application/json'
            $"((server))/api/v1/automations/bench-on-overlap-probe" $body)
        let after = (http get --headers (auth-header) $"((server))/api/v1/automations/bench-on-overlap-probe")
        let overlap = ($after | get -o on_overlap | default 'none')
        let delete_headers = ((auth-header) | merge {"If-Match": $"\"($rev)\""})
        let _ = (http delete --headers $delete_headers
            $"((server))/api/v1/automations/bench-on-overlap-probe")
        $overlap
    })
    $rows = ($rows | append {
        facet:  'P1 automation replace keeps on_overlap'
        ok:     ($scratch == 'skip')
        detail: ($"on_overlap after a bare replace: ($scratch)")
    })

    # The cutover's CLI facade (fabro-cc1b): the host scripts leave `.seeds`
    # only after these verbs prove themselves on the bench's own items.
    $rows = ($rows | append (work-cli-checks))
    $rows
}

# The CLI facade over work items (cutover stage 1b, fabro-cc1b). This is the
# first half of the full-chain probe the stage-6 retirement of the seeds
# binary needs: the host scripts (friction-score, salvage-sweep, push-gate,
# close-claim-check) stop reading `.seeds` and start calling these verbs, so
# the verbs run here against the bench's own server first.
#
# The items are the bench's own (`cli-test` label, project fabro-proof), are
# created in this run and closed in this run, so the loop's queue never sees
# them. Bodies travel through stdin on purpose: a real item body must never
# be spelled onto a shell command line.
def work-cli-checks []: nothing -> list<record> {
    mut rows = []
    # A facet that exercises a NEW verb resolves FABRO_BIN first (run-mini
    # precedent): the bench's installed binary lags the tree, so a stale
    # binary reports itself instead of blaming the server.
    let fabro = ($env.FABRO_BIN? | default ('~/.fabro/bin/fabro' | path expand))
    let project = 'fabro-proof'
    let tag = (date now | format date '%m%d-%H%M%S')
    let title = $"work-cli probe ($tag)"
    let body = $"work-cli probe body ($tag)\nsecond line of the same body"
    let reason = 'work-cli probe: closed by the bench in the same run'

    let created = ($body | ^$fabro work --server (server) create --project $project --title $title --body-file - --label cli-test --label $"bench=($tag)" --json | complete)
    let key = (if $created.exit_code == 0 {
        $created.stdout | from json | get -o itemKey | default ''
    } else {
        ''
    })
    # Without an item no later verb can say anything true, so every row
    # carries the create failure instead of a second, derived complaint.
    let why = (if ($key | is-empty) {
        $"create failed: exit ($created.exit_code) — ($created.stderr | str trim | str substring 0..200)"
    } else {
        ''
    })
    print $"== workbench: work CLI probe ($key)"

    # Read path first, while the item is still open: `work list` must contain
    # what `work create` filed. GitHub's label-filtered list converges a few
    # seconds after a write (the label index, not our server — measured on
    # denkhaus/work#10..#12), so poll briefly: the row asserts the durable
    # property, not the index's mood.
    mut list_ok = false
    mut list_detail = $why
    if ($why | is-empty) {
        mut attempts = 0
        loop {
            $attempts = ($attempts + 1)
            let listed = (do { ^$fabro work --server (server) list --project $project --json } | complete)
            let items = (try { $listed.stdout | from json } catch { [] })
            if ($listed.exit_code == 0) and (($items | where itemKey == $key | length) > 0) {
                $list_ok = true
                $list_detail = $"($key) in the open list after ($attempts) reads"
                break
            }
            if $attempts >= 6 {
                $list_detail = $"list exit ($listed.exit_code): ($listed.stderr | str trim | str substring 0..160)"
                break
            }
            sleep 2sec
        }
    }
    $rows = ($rows | append {facet: 'P4 work CLI list', ok: $list_ok, detail: $list_detail})

    # The selector path: a BARE NUMBER has to compose against the project's
    # tracker repo, which no unit test can prove end to end. `show` prints the
    # head table and the body verbatim, so the tag must survive both — and it
    # only ever travelled as stdin.
    mut roundtrip_ok = false
    mut roundtrip_detail = $why
    if ($why | is-empty) {
        let number = ($key | split row '#' | last)
        let shown = (do { ^$fabro work --server (server) show --project $project $number } | complete)
        let body_seen = ($shown.exit_code == 0) and ($shown.stdout | str contains $tag)
        let closed = (do { ^$fabro work --server (server) close --project $project $key --reason $reason } | complete)
        let close_ok = ($closed.exit_code == 0) and ($closed.stderr | str contains 'Closed')
        $roundtrip_ok = $body_seen and $close_ok
        $roundtrip_detail = $"($key): show-by-number=($shown.exit_code) body=($body_seen) close=($closed.exit_code)"
    }
    $rows = ($rows | append {
        facet:  'P4 work CLI create -> show -> close roundtrip'
        ok:     $roundtrip_ok
        detail: $roundtrip_detail
    })

    # A live queue is normal mid-loop (the loop lane holds claims), so the row
    # asserts the verb, not an empty ledger: either the claims table or the
    # explicit empty message.
    let claims = (do { ^$fabro work --server (server) claims --project $project } | complete)
    let claims_ok = ($claims.exit_code == 0) and ((($claims.stdout | str contains 'CLAIM') or ($claims.stderr | str contains 'No live claims')))
    mut claims_detail = ($claims.stderr | str trim | str substring 0..160)
    if $claims_ok {
        if ($claims.stderr | str contains 'No live claims') {
            $claims_detail = 'empty ledger'
        } else {
            $claims_detail = $"live claims read: ($claims.stdout | lines | skip 1 | length)"
        }
    }
    $rows = ($rows | append {facet: 'P4 work CLI claims', ok: $claims_ok, detail: $claims_detail})
    $rows
}

# A run PR auto-merging MID-BENCH moves origin/main; the next cwd-based
# create then refuses (target derivation demands local HEAD == origin tip —
# running a stale ancestor silently would probe old code). Resync before
# every create; a dirty tree is left alone so the refusal stays loud.
def ensure-sync []: nothing -> nothing {
    let f = (do { git fetch --prune origin --quiet } | complete)
    if $f.exit_code != 0 { return }
    let local = (do { git rev-parse HEAD } | complete | get stdout | str trim)
    let remote = (do { git rev-parse origin/main } | complete | get stdout | str trim)
    let dirty = (do { git status --porcelain } | complete | get stdout | str trim)
    if ($local != $remote) and ($dirty | is-empty) {
        let _ = (do { git checkout main --quiet; git reset --hard origin/main --quiet } | complete)
        print $"== workbench: resynced to moved origin/main"
    }
}

# The innermost pebble stream event of a run-stream row: the record at
# item.record.body.ev.custom.event.event, carrying ONE variant key
# (UserInput, Warning, ToolCallCompleted, ...). Rows of other custom
# kinds carry a STRING there — callers MUST guard with
# `describe | str starts-with "record"` before variant access. A string
# cell-path argument (`get -o "a.b.c") does NOT split on dots — it looks
# up one literal column name — so the path stays bare here.
def pebble-event [e: record]: nothing -> any {
    $e | get -o item.record.body.ev.custom.event.event
}

def probe-run [name: string, expect: string, bench_id: string]: nothing -> record {
    let t0 = (date now)
    ensure-sync
    if $name starts-with 'probe-23' or $name starts-with 'probe-24' {
        proof-ensure
    }
    if $name starts-with 'probe-25' {
        probe25-target-ensure
    }
    # probe scripts execute nu in the sandbox — test-local (buildpack-deps)
    # ships no nushell; the toolchain env has nu via mise shims.
    # expect rides as a LABEL: a failed run in the list must be recognizable
    # as red-by-design from the outside (bench probes 06/09/15 fail on purpose)
    let created = (do { ^$FABRO create $name --label $"bench=($bench_id)" --label $"expect=($expect)" --environment toolchain --json --server (server) } | complete)
    if $created.exit_code != 0 {
        let msg = ($created.stderr | str trim)
        # expect 'refused': admission must REJECT the graph and say why
        # (fabro-70af: unknown x.* -> fork.x_attribute_known).
        if $expect == 'refused' {
            let named = ($msg | str contains 'x_attribute_known') or ($msg | str contains 'unknown attribute')
            return {facet: $name, ok: $named, detail: ($msg | str substring 0..140)}
        }
        # stderr starts with the benign project.toml warning — the real
        # refusal follows; show the TAIL
        return {facet: $name, ok: false, detail: ($msg | str substring (-160)..)}
    }
    if $expect == 'refused' {
        return {facet: $name, ok: false, detail: 'expected an admission refusal, but create succeeded'}
    }
    let run_id = ($created.stdout | from json | get -o run_id | default '')
    if ($run_id | is-empty) { return {facet: $name, ok: false, detail: 'no run_id'} }
    let started = (do { ^$FABRO start $run_id --server (server) } | complete)
    if $started.exit_code != 0 {
        return {facet: $name, ok: false, detail: ($started.stderr | str trim | str substring 0..140)}
    }

    if $name == 'probe-08-interview' {
        let answered = (hitl-answer $run_id)
        if not $answered { return {facet: $name, ok: false, detail: 'hitl questions not fully answered'} }
    }

    let waited = (do { ^$FABRO wait $run_id --json --server (server) } | complete)
    let info = (try { $waited.stdout | from json } catch { null })
    if $info == null { return {facet: $name, ok: false, detail: 'no terminal json'} }
    let status = ($info | get -o status | default '?')
    let secs = ((((date now) - $t0) | into int) / 1_000_000_000)

    let ok = if $expect == 'succeeded' { $status == 'succeeded' } else { $status == 'failed' }
    let detail = if $ok { $"($status) in ($secs)s" } else { $"expected ($expect), got ($status)" }

    if $ok and $name == 'probe-04-runtools' {
        let children = (http get --headers (auth-header) $"((server))/api/v1/runs?limit=50" | get data | where {|r| (($r | get -o parent_id | default '') == $run_id)})
        let child_ok = ($children | length) > 0
        return {facet: $name, ok: $child_ok, detail: ($detail + $" | children=($children | length)") }
    }
    if $ok and $name == 'probe-07-artifacts' {
        let evs = (http get --headers (auth-header) $"((server))/api/v1/runs/($run_id)/events?limit=1000" | get -o data | default [])
        let collected = ($evs | where {|e| (($e | get -o item.record.kind | default '') == 'artifact.collected')} | length)
        return {facet: $name, ok: ($collected > 0), detail: ($detail + $" | artifact.collected=($collected)") }
    }
    if $ok and $name == 'probe-06-guards' {
        let api = (http get --headers (auth-header) $"((server))/api/v1/runs/($run_id)")
        let reason = ($api | get -o lifecycle | get -o status | get -o reason | default '' | str lowercase)
        let deadlocked = ($reason | str contains 'deadlock')
        return {facet: $name, ok: $deadlocked, detail: ($detail + ' reason=' + $reason) }
    }
    if $ok and $name == 'probe-30-three-reds' {
        # work#1057: the third consecutive red must reach the HUMAN as a
        # deadlock — reason=deadlock is the whole facet. The two failed
        # shapes it discriminates: workflow_error (the breaker
        # loop_restart_signature_limit cutting the third loop signature
        # when the cap sat at generation < 3 — first drive, run
        # 01M636T77HA3QSKK4F6G93AQFV) and succeeded (a plain gate-green
        # -> exit edge beside the kind edge breaking fabro-843d
        # sole_exit_route — second drive, run
        # 01M63706VG9110QPCB8PB4TJXS).
        let api = (http get --headers (auth-header) $"((server))/api/v1/runs/($run_id)")
        let reason = ($api | get -o lifecycle | get -o status | get -o reason | default '' | str lowercase)
        let deadlocked = ($reason | str contains 'deadlock')
        return {facet: $name, ok: $deadlocked, detail: ($detail + ' reason=' + $reason) }
    }
    if $ok and $name == 'probe-32-observation-record' {
        # ADR-0038 stage 1: the tool call, the platform record, AND the
        # live fold must all hold — the pebble ToolCallCompleted for
        # fabro_observation_record, the observation.recorded record with
        # the exact category and text on the stream, and the projection
        # folding the entry onto the recorder stage's observations.
        let evs = (http get --headers (auth-header) $"((server))/api/v1/runs/($run_id)/events?limit=2000" | get -o data | default [])
        let raw = ($evs | to json -r)
        let called = ($raw | str contains '"tool_name":"fabro_observation_record"')
        let records = ($evs | where {|e| (($e | get -o item.record.kind | default '') == 'observation.recorded')})
        let record_ok = ($records | length) > 0
        let entry = ($records | first | get -o item.record | default {})
        let payload_ok = (($entry | get -o category | default '') == 'note') and (($entry | get -o text | default '') == 'probe-32 recorded an observation')
        let state = (http get --headers (auth-header) $"((server))/api/v1/runs/($run_id)/state")
        let stages = ($state | get -o stages | default {})
        let stage_key = ($stages | columns | where {|k| $k | str starts-with 'recorder'} | first)
        let stage = ($stages | get -o $stage_key | default {})
        let folded = ($stage | get -o observations | default [])
        let fold_ok = (($folded | length) == 1) and (($folded | first | get -o category | default '') == 'note') and (($folded | first | get -o text | default '') == 'probe-32 recorded an observation')
        let ok32 = ($called and $record_ok and $payload_ok and $fold_ok)
        return {facet: $name, ok: $ok32, detail: ($detail + $" | tool_call=($called) records=(($records | length)) payload=($payload_ok) fold=($fold_ok)") }
    }
    if $ok and $name == 'probe-33-observation-contract' {
        # ADR-0038 stage 1: the violation's failure must TEACH — the run
        # went red (the expect facet), and the events carry the presence
        # contract's reason: the tool name and the explicit empty entry.
        let evs = (http get --headers (auth-header) $"((server))/api/v1/runs/($run_id)/events?limit=2000" | get -o data | default [])
        let raw = ($evs | to json -r)
        let names_tool = ($raw | str contains 'fabro_observation_record')
        let teaches_empty = ($raw | str contains 'nothing durable to record')
        let bad_output = ($raw | str contains 'bad_output')
        let ok33 = ($names_tool and $teaches_empty and $bad_output)
        return {facet: $name, ok: $ok33, detail: ($detail + $" | names_tool=($names_tool) empty_entry=($teaches_empty) class=($bad_output)") }
    }
    if $ok and $name == 'probe-34-close-gate' {
        # ADR-0038 stage 3: the whole chain in one facet — the run's own
        # observation (the (run, seq) identity off the folded stage
        # view), a user claim of the closer item for THIS run (the
        # claims-history edge), the user link of a blocker item to that
        # observation, then BOTH close arms: unforced -> 409 naming the
        # blocker, forced -> 200 with overriddenRadius echoing exactly
        # the blocker. Pure HTTP against the stack.
        let state = (http get --headers (auth-header) $"((server))/api/v1/runs/($run_id)/state")
        let stages = ($state | get -o stages | default {})
        let stage_key = ($stages | columns | where {|k| $k | str starts-with 'recorder'} | first)
        let observations = ($stages | get -o $stage_key | default {} | get -o observations | default [])
        let seq = ($observations | first | get -o seq | default 0)
        let text_ok = (($observations | first | get -o text | default '') == 'probe-34 radius blocker observation')
        let project = 'fabro-proof'
        let tag = (date now | format date '%m%d-%H%M%S')
        let items_url = $"((server))/api/v1/projects/($project)/work-items"
        let closer = (http post --headers (auth-header) -t 'application/json' $items_url {
            title: $"probe-34 closer ($tag)",
            body: $"probe-34 closer body ($tag)",
            labels: [$"bench=($tag)"]
        })
        let blocker = (http post --headers (auth-header) -t 'application/json' $items_url {
            title: $"probe-34 blocker ($tag)",
            body: $"probe-34 blocker body ($tag)",
            labels: [$"bench=($tag)"]
        })
        let closer_key = ($closer | get -o itemKey | default '')
        let blocker_key = ($blocker | get -o itemKey | default '')
        let setup_ok = ($text_ok and ($seq > 0) and (not ($closer_key | is-empty)) and (not ($blocker_key | is-empty)))
        if not $setup_ok {
            return {facet: $name, ok: false, detail: ($detail + $" | setup: text=($text_ok) seq=($seq) closer=($closer_key) blocker=($blocker_key)") }
        }
        # The claims-history edge: THIS run claimed the closer item.
        let grant = (http post --headers (auth-header) -t 'application/json' $"((server))/api/v1/projects/($project)/claims" {
            itemKey: $closer_key,
            runId: $run_id,
            lane: 'loop'
        })
        let granted = (($grant | get -o outcome | default '') in ['granted' 'already_held'])
        # The link edge: the blocker item is linked to the observation.
        let link = (http post --headers (auth-header) -t 'application/json' $"($items_url)/link" {
            itemKey: $blocker_key,
            runId: $run_id,
            seq: $seq
        })
        let linked = (($link | get -o outcome | default '') == 'linked')
        # Arm 1 — unforced close: 409, the listing names the blocker.
        # Status discrimination by body SHAPE, not `metadata`: the -e
        # error-response value carries no http_response metadata here, a
        # 200 body has item/overriddenRadius keys, the refusal has
        # errors[0].detail.
        let refusal = (http post -e --headers (auth-header) -t 'application/json' $"($items_url)/close" {
            itemKey: $closer_key,
            reason: $"probe-34 ($tag): unforced close must refuse over the open radius"
        })
        let refusal_detail = ($refusal | get -o errors | default [] | first | get -o detail | default '')
        let refused = (($refusal | get -o errors) != null) and ($refusal_detail | str contains $blocker_key) and ($refusal_detail | str contains 'force')
        # Arm 2 — forced close: 200, the echo names exactly the blocker.
        let forced = (http post --headers (auth-header) -t 'application/json' $"($items_url)/close" {
            itemKey: $closer_key,
            reason: $"probe-34 ($tag): forced over the open radius",
            force: true
        })
        let overridden = ($forced | get -o overriddenRadius | default [])
        let forced_ok = (($forced | get -o item | get -o state | default '') == 'closed') and (($overridden | length) == 1) and (($overridden | first | get -o itemKey | default '') == $blocker_key)
        # Cleanup: the blocker closes with an empty radius of its own.
        let _ = (http post -e --headers (auth-header) -t 'application/json' $"($items_url)/close" {
            itemKey: $blocker_key,
            reason: $"probe-34 ($tag): bench cleanup"
        })
        let ok34 = ($granted and $linked and $refused and $forced_ok)
        return {facet: $name, ok: $ok34, detail: ($detail + $" | granted=($granted) linked=($linked) refused=($refused) refusal_detail=($refusal_detail | str substring 0..80) forced=($forced_ok) seq=($seq)") }
    }
    if $ok and ($name == 'probe-26-gate-bounce' or $name == 'probe-26-gate-bounce-catchall') {
        # work#1029: engine conclusion, terminal event, and platform
        # record must agree, and the publish path must follow the
        # record. The fixed shape asserts succeeded + PR; the catch-all
        # twin asserts workflow_error + NO PR (the downgraded control).
        let api = (http get --headers (auth-header) $"((server))/api/v1/runs/($run_id)")
        let reason = ($api | get -o lifecycle | get -o status | get -o reason | default '' | str lowercase)
        let evs = (http get --headers (auth-header) $"((server))/api/v1/runs/($run_id)/events?limit=1000" | get -o data | default [])
        let terminal = ($evs | where {|e| (($e | get -o item.record.kind | default '') == 'run.lifecycle')} | last)
        let transition = ($terminal | get -o item.record.transition | default '?')
        # The local stack has no engine publish step yet (fabro-ac40):
        # the bench bridges it manually (publish-bridge.nu, docker cp the
        # snapshot + push + PR) — driven for the fixed shape ONLY, exactly
        # as the mini facet drives it; the catch-all twin must stay
        # UNPUBLISHED (nothing bridges it and nothing auto-publishes: its
        # downgraded record refuses the publish path — the #1029 symptom:
        # the branch was never pushed, the work had to be salvaged by
        # hand). The assert sits on the BRANCH PUSH (the deterministic,
        # exact-#1029 signal); the PR leg is the bridge's own
        # known-flaky surface (server-PR title generation, the mini
        # facet owns it).
        if $name == 'probe-26-gate-bounce' {
            let bridge = (do { nu scripts/publish-bridge.nu $run_id } | complete)
            let pushed = (do { git ls-remote origin $"refs/heads/fabro/run/($run_id)" } | complete)
            let branch_sha = ($pushed.stdout | str trim)
            let agree = ($transition == 'succeeded')
            let published = ($branch_sha | is-not-empty)
            let ok26 = ($agree and $published)
            let short = (if $published { $branch_sha | str substring 0..12 } else { 'none' })
            return {facet: $name, ok: $ok26, detail: ($detail + $" | terminal=($transition) branch=($short) bridge=($bridge.exit_code) reason=($reason)")}
        }
        let pushed_c = (do { git ls-remote origin $"refs/heads/fabro/run/($run_id)" } | complete)
        let split = ($reason | str contains 'workflow_error')
        let unpublished = (($pushed_c.stdout | str trim) | is-empty)
        let ok26c = ($split and $unpublished and ($transition == 'succeeded'))
        let branch_state = (if $unpublished { 'none' } else { 'pushed' })
        return {facet: $name, ok: $ok26c, detail: ($detail + $" | terminal=($transition) branch=($branch_state) reason=($reason)")}
    }
    if $ok and $name == 'probe-16-hosthook' {
        # The host hook (sandbox = false) must have read a context file with
        # a non-empty run id. Its exit code shows up in the run's hook notes
        # as a failed hook; a green probe means the file contract holds
        # (petri 5bdb90c, fabro-b714) - the judgment-shadow hook on mirtuell
        # still shows the failure this check names.
        let evs = (http get --headers (auth-header) $"((server))/api/v1/runs/($run_id)/events?limit=2000" | get -o data | default [])
        let notes = ($evs | where {|e| (($e | get item | to json -r) | str contains 'probe-hosthook')})
        let failed = ($notes | where {|e| ((($e | get item | to json -r) | str contains 'hook exited with code'))})
        let ran = ($notes | where {|e| ((($e | get item | to json -r) | str contains '"state":"executed"'))})
        return {
            facet:  $name
            ok:     ((($failed | length) == 0) and (($ran | length) > 0))
            detail: ($detail + $" | hook notes=($notes | length) ran=($ran | length) failed=($failed | length)")
        }
    }
    if $ok and $name == 'probe-23-work-claim-release' {
        # Work-line roundtrip evidence (fabro-6041): the run stream must
        # carry BOTH platform records — work.claimed (the atomic grant) and
        # work.released (the escape hatch). Empty lane or a failed release
        # (fabro-9166 class) is RED, never green-vacuous.
        let evs = (http get --headers (auth-header) $"((server))/api/v1/runs/($run_id)/events?limit=1000" | get -o data | default [])
        let claimed = ($evs | where {|e| (($e | get -o item.record.kind | default '') == 'work.claimed')} | length)
        let released = ($evs | where {|e| (($e | get -o item.record.kind | default '') == 'work.released')} | length)
        let roundtrip = ($claimed > 0) and ($released > 0)
        return {facet: $name, ok: $roundtrip, detail: ($detail + $" | work.claimed=($claimed) work.released=($released)") }
    }
    if $ok and $name == 'probe-24-tool-error-wrap' {
        # c98c seam (fabro-6041): the agent forced two failing run-tool
        # calls; every follow-up request must RENDER the error flag into
        # content for openai-wire profiles — so the provider wire never
        # drops it and the unsupported_control warning never fires.
        # Count the REAL pebble events, never raw string matches: the
        # probe prompt itself names 'unsupported_control', so a
        # contains-grep counts the UserInput echo (the first bench round
        # read green runs as red through exactly that artifact). The fix
        # landed 2026-10-24 (pebble 47a036fd: the marker replaces the
        # flag); this row is the regression net for the deployed path.
        let evs = (http get --headers (auth-header) $"((server))/api/v1/runs/($run_id)/events?limit=2000" | get -o data | default [])
        let errors = ($evs | where {|e|
            let pe = (pebble-event $e)
            (($pe | describe | str starts-with 'record') and ($pe.ToolCallCompleted?.is_error? | default false))
        } | length)
        let warns = ($evs | where {|e|
            let pe = (pebble-event $e)
            (($pe | describe | str starts-with 'record') and (($pe.Warning?.kind? | default '') == 'unsupported_control'))
        } | length)
        let wire_ok = ($errors >= 2) and ($warns == 0)
        return {facet: $name, ok: $wire_ok, detail: ($detail + $" | tool_errors=($errors) unsupported_control=($warns)") }
    }
    if $ok and $name == 'probe-25-work-roundtrip' {
        # Work-item lifecycle roundtrip on a CLAIMED item (fabro-6041,
        # user direction 2026-10-25; rescued 2026-10-27 for the
        # claim-binding core denkhaus/work#991: update/close refuse
        # without a live claim held by the run, so the pre-#991
        # create-first contract went red BY DESIGN). The bench ensured a
        # p1 target item before the run; the agent claims it via
        # fabro_work_next, then show, update, close. Counted on REAL
        # pebble ToolCallCompleted events, never string greps across the
        # whole stream; the item is found by its exact fixed title
        # (newest closed match = this bench's item). This is the
        # closeout agent's order of operations — fabro-9986's laps rely
        # on it.
        let evs = (http get --headers (auth-header) $"((server))/api/v1/runs/($run_id)/events?limit=2000" | get -o data | default [])
        let calls = ($evs | where {|e|
            let pe = (pebble-event $e)
            (($pe | describe | str starts-with 'record') and ($pe.ToolCallCompleted? != null)
                and (not ($pe.ToolCallCompleted?.is_error? | default false)))
        })
        let tools_ok = (['fabro_work_next' 'fabro_work_show' 'fabro_work_update' 'fabro_work_close'] | all {|t|
            ($calls | where {|e| (((pebble-event $e) | get -o ToolCallCompleted | to json -r) | str contains $t)} | length) > 0
        })
        let newest = (do { ^gh issue list --repo denkhaus/work --state closed --search '"probe-25 roundtrip item" in:title' --json number,body --jq 'sort_by(.number) | last | (.number | tostring) + " " + .body' } | complete | get stdout | str trim)
        let state_ok = ($newest | str contains 'marker-create') and ($newest | str contains 'marker-update')
        let roundtrip = $tools_ok and $state_ok
        return {facet: $name, ok: $roundtrip, detail: ($detail + $" | lifecycle_calls=($calls | length) item#=($newest | split row ' ' | first) closed=($state_ok)") }
    }
    {facet: $name, ok: $ok, detail: $detail}
}

# The mini loop runs THE canonical bench seed: fixed wording, fixed prestate.
# Before every bench: reset bench/canonical.nu + tests to the tracked stub,
# then ensure the seed row is open with the exact same text — runs stay
# comparable across benches and upstream merges (user directive).
# ALL tracker mutations go through the seeds app, never manual JSON edits.
# Work-line prestate (fabro-6041): the central tracker policy holds — ALL
# items live on denkhaus/work, including proof items. Idempotent, no seeds:
# (1) register project fabro-proof on the server (PUT upsert; targetRepo
#     denkhaus/fabro-test is the manual-run resolution fallback),
# (2) ensure the two marked proof items are open (host gh; reopen if a
#     bench run left them closed),
# (3) report live claims — a stuck claim from a crashed run shrinks the
#     claimable pool; released by the 30-min orphan arm if the API path
#     cannot (fabro-9166). Logged, never fatal: the pool has two items.
# The bench's work project (fabro-proof on the central tracker). MUST run
# before anything creates an automation: since f1a9 (fork.25) an automation
# create refuses without a REGISTERED work_project
# (automation_work_project_required) — the platform checks create a scratch
# automation, so the project has to exist first.
def project-ensure []: nothing -> nothing {
    let body = {
        displayName: 'Fabro Proof'
        trackerProvider: 'github'
        trackerRepo: 'denkhaus/work'
        targetRepo: 'denkhaus/fabro-test'
        projectLabel: 'project:fabro-proof'
        laneLabels: {proof: 'lane:proof'}
        claimLabelPrefix: 'fabro:run:'
        claimCommentEnabled: false
        backpressureOpenPrCap: 1
    }
    let put = (try { http put --headers (auth-header) $"(server)/api/v1/projects/fabro-proof" --content-type application/json ($body | to json -r) } catch {|err| null })
    if $put == null {
        print 'project-ensure: fabro-proof upsert failed — automation creates will refuse (automation_work_project_required)'
    }
}

# Facet 10 (slack notification) needs a PLATFORM-side route: the engine has
# ignored workflow-declared [run.notifications] by contract since 2026-09-06
# (explicit exclusion, warn at admission), and the local stack settings never
# carried one — the facet went red the moment a bench asserted the record
# without provisioning the route (2026-10-24, bench 1024-224941). The server
# folds settings [run.*] into every run spec (manifest run settings), so the
# route rides the stack's settings.toml. Idempotent: a present block is a
# no-op; a merge restarts the container once and waits for health.
def route-ensure []: nothing -> nothing {
    let container = 'fabro-lokal'
    let settings = '/storage/.home/settings.toml'
    let has = (do { ^docker exec $container grep -c 'run.notifications.terminal' $settings } | complete)
    let count = ($has.stdout | str trim)
    if $has.exit_code == 0 and ($count | is-not-empty) and ($count != '0') {
        return
    }
    let block = '
cat >> /storage/.home/settings.toml <<EOF

[run.notifications.terminal]
enabled = true
provider = "slack"
events = ["run.completed", "run.failed"]

[run.notifications.terminal.slack]
channel = "#dev-fabro"
EOF'
    let merge = (do { ^docker exec $container sh -c $block } | complete)
    if $merge.exit_code != 0 {
        print $"route-ensure: settings merge failed — facet 10 will go red: ($merge.stderr | str trim | str substring 0..120)"
        return
    }
    let _ = (do { ^docker restart $container } | complete)
    # poll health up to 60s; a bench against a half-started stack fails
    # everywhere, so wait it out loudly
    mut healthy = false
    for _ in 1..30 {
        let h = (try { http get $"(server)/health" } catch {|err| null })
        if ($h | get -o status | default '') == 'ok' { $healthy = true; break }
        sleep 2sec
    }
    if not $healthy {
        print 'route-ensure: container did not return healthy after restart — the bench will surface it'
    } else {
        print '== workbench: route-ensure added the slack notification route (container restarted)'
    }
}

def proof-ensure []: nothing -> nothing {
    project-ensure
    for n in [3 4] {
        let st = (do { ^gh issue view $n --repo denkhaus/work --json state --jq state } | complete | get stdout | str trim)
        if $st == 'CLOSED' {
            let re = (do { ^gh issue reopen $n --repo denkhaus/work } | complete)
            if $re.exit_code == 0 { print $"proof-ensure: reopened denkhaus/work#($n)" }
        }
    }
    let claims = (try { http get --headers (auth-header) $"(server)/api/v1/projects/fabro-proof/claims" } catch {|err| {data: []} })
    let live = ($claims | get -o data | default [] | length)
    if $live > 0 {
        print $"proof-ensure: ($live) live claims on fabro-proof — orphan arm heals in 30m or less if stuck"
    }
}

# probe-25's claim target (rescue 2026-10-27, denkhaus/work#991): the
# lifecycle agent works on a CLAIMED item, and a claim only comes through
# fabro_work_next — which grants the highest-priority FREE item of the
# lane. Ensuring a fresh p1 item of the exact fixed title (body carries
# marker-create) right before the run makes the grant deterministic:
# it is the only free prio:p1 item in project fabro-proof / lane proof.
# A new item per run keeps the assertion simple (newest closed match);
# facet 23 runs EARLIER and releases whatever it claimed, so the grant
# does not race the sibling probe.
def probe25-target-ensure []: nothing -> nothing {
    project-ensure
    let created = (do {
        ^gh issue create --repo denkhaus/work --title 'probe-25 roundtrip item' --body 'Roundtrip body: created by the bench probe. marker-create' --label 'project:fabro-proof' --label 'lane:proof' --label 'prio:p1'
    } | complete)
    if $created.exit_code != 0 {
        fail $"probe25-target-ensure: gh issue create failed: ($created.stderr | str trim | str substring 0..200)"
    }
    print $"probe25-target-ensure: filed ($created.stdout | str trim) — p1 claim target"
}

def seed-ensure []: nothing -> nothing {
    # (0) deterministic base: whatever a half-failed prior dance left behind
    #     (unpushed commit, stale bench branch), start from origin/main.
    #     The reset is destructive, so a dirty tree REFUSES to run — an
    #     uncommitted workbench edit was wiped exactly this way once.
    let dirty0 = (do { git status --porcelain } | complete | get stdout | str trim)
    if ($dirty0 | is-not-empty) { fail $"seed-ensure: workbench tree is dirty — commit or stash first: ($dirty0 | lines | first)" }
    let fetch = (do { git fetch --prune origin --quiet } | complete)
    if $fetch.exit_code != 0 { fail $"seed-ensure: git fetch: ($fetch.stderr | str trim | str substring 0..200)" }
    let co = (do { git checkout main --quiet } | complete)
    if $co.exit_code != 0 { fail $"seed-ensure: checkout main: ($co.stderr | str trim | str substring 0..200)" }
    let reset = (do { git reset --hard origin/main --quiet } | complete)
    if $reset.exit_code != 0 { fail $"seed-ensure: reset to origin/main: ($reset.stderr | str trim | str substring 0..200)" }
    # (a) reset the canonical files to the prestate copies
    cp .fabro/workbench/prestate/canonical.nu bench/canonical.nu
    cp .fabro/workbench/prestate/test-canonical.nu tests/test-canonical.nu
    # (b) canonical-seed exclusivity + re-pin via the seeds app.
    #     Manual .seeds JSON edits are discouraged — the hand-rolled join
    #     collapsed the tracker to one literal-\n line once (bench 0926-080715).
    let open_ids = (^mise exec -- seeds list --status open --format ids | lines | where {|l| ($l | str trim) != ''})
    let others = ($open_ids | where {|id| $id != 'fabro-test-9001'})
    if ($others | is-not-empty) {
        let _ = (do { ^mise exec -- seeds close ...$others --reason 'bench: canonical-seed exclusivity (one bench seed per run)' } | complete)
    }
    let desc = 'Replace the error-make stub in bench/canonical.nu so it prints the exact string canonical-ok-9001 (tracked acceptance: tests/test-canonical.nu). Acceptance: nu tests/test-canonical.nu is green and the stub is gone.'
    # idempotent re-pin: `seeds update` always rewrites updatedAt, which would
    # dirty the tree on every bench run and force a pointless prestate PR —
    # update only when title or status actually deviate
    let cur = (do { ^mise exec -- seeds show fabro-test-9001 --format json } | complete)
    let issue = if $cur.exit_code == 0 { $cur.stdout | from json | get -o issue | default {} } else { {} }
    let pinned = (($issue | get -o title | default '') == 'Implement canonical_mark in bench/canonical.nu') and (($issue | get -o status | default '') == 'open')
    if not $pinned {
        let upd = (do { ^mise exec -- seeds update fabro-test-9001 --status open --title 'Implement canonical_mark in bench/canonical.nu' --set-description $desc } | complete)
        if $upd.exit_code != 0 {
            fail $"seed-ensure: cannot re-pin fabro-test-9001: ($upd.stderr | str trim | str substring 0..200) — restore the row from git history, fixed id; seeds create cannot mint it"
        }
    }
    # (c) land the prestate on the PROTECTED main through the PR dance.
    #     `fabro create` refuses a HEAD that is not on origin (clone-based
    #     target derivation) and direct pushes are rejected by branch
    #     protection — so the commit rides: bench branch -> PR -> squash
    #     merge (--admin) -> local main resynced to the squashed commit.
    #     Every step is exit-checked: the old silent `git push | complete`
    #     left an unpushed commit and blocked the mini leg (fabro-4b84).
    let dirty = (do { git status --porcelain } | complete | get stdout | str trim)
    if ($dirty | is-empty) {
        print '== workbench: canonical seed ensured (fabro-test-9001, fixed wording) — prestate already on origin/main'
        return
    }
    let branch = 'bench/prestate'
    let sw = (do { git checkout -B $branch --quiet } | complete)
    if $sw.exit_code != 0 { fail $"seed-ensure: branch ($branch): ($sw.stderr | str trim | str substring 0..200)" }
    let add = (do { git add bench/canonical.nu tests/test-canonical.nu .seeds/issues.jsonl } | complete)
    if $add.exit_code != 0 { fail $"seed-ensure: git add: ($add.stderr | str trim | str substring 0..200)" }
    let cm = (do { git -c user.name=denkhaus -c user.email=denkhaus@users.noreply.github.com commit -m 'bench: reset canonical prestate + reopen seed fabro-test-9001' --quiet } | complete)
    if $cm.exit_code != 0 { fail $"seed-ensure: commit: ($cm.stderr | str trim | str substring 0..200)" }
    let push = (do { git push --force-with-lease origin $"($branch):($branch)" --quiet } | complete)
    if $push.exit_code != 0 { fail $"seed-ensure: push ($branch): ($push.stderr | str trim | str substring 0..200)" }
    # reuse an OPEN PR on the bench branch when a prior dance stalled mid-way
    # (gh pr view <branch> also returns CLOSED pull requests — merging one
    # always fails with 'Base branch was modified')
    let existing = (do { ^gh pr list -R denkhaus/fabro-test --head $branch --state open --json number,url --limit 1 } | complete)
    let open_prs = if $existing.exit_code == 0 { $existing.stdout | from json } else { [] }
    let pr_url = if ($open_prs | is-not-empty) {
        $open_prs | first | get url
    } else {
        let pr_title = 'bench: reset canonical prestate + reopen seed fabro-test-9001'
        let pr_body = 'Deterministic mini-loop prestate: canonical stub reset + fabro-test-9001 re-pinned. Red `tests` by design until the mini run lands the fix. Squash-merge; the workbench resyncs local main afterwards.'
        let pr = (do { ^gh pr create -R denkhaus/fabro-test --base main --head $branch --title $pr_title --body $pr_body } | complete)
        if $pr.exit_code != 0 { fail $"seed-ensure: gh pr create: ($pr.stderr | str trim | str substring 0..200)" }
        $pr.stdout | str trim
    }
    # Required checks must REPORT before --admin may merge. The prestate is
    # red BY DESIGN (tests fail against the stub; the mini run makes them
    # green), so wait for every check to be COMPLETED — do not demand green —
    # then merge with the admin override.
    mut ready = false
    for _ in 1..60 {
        let roll = (do { ^gh pr view $pr_url -R denkhaus/fabro-test --json statusCheckRollup } | complete)
        if $roll.exit_code == 0 {
            let entries = ($roll.stdout | from json | get -o statusCheckRollup | default [])
            if ($entries | is-not-empty) {
                let pending = ($entries | where {|c| ($c | get -o status | default 'COMPLETED') != 'COMPLETED'})
                if ($pending | is-empty) { $ready = true; break }
            }
        }
        sleep 5sec
    }
    if not $ready { fail $"seed-ensure: PR checks never finished reporting: ($pr_url)" }
    let merge = (do { ^gh pr merge $pr_url -R denkhaus/fabro-test --squash --admin --delete-branch } | complete)
    if $merge.exit_code != 0 {
        # a 504 can time out the RESPONSE while the merge itself succeeds —
        # verify the PR state before declaring failure
        let st = (do { ^gh pr view $pr_url -R denkhaus/fabro-test --json state } | complete)
        let state = if $st.exit_code == 0 { $st.stdout | from json | get -o state | default '' } else { '' }
        if $state != 'MERGED' { fail $"seed-ensure: gh pr merge ($pr_url): ($merge.stderr | str trim | str substring 0..200)" }
    }
    let f2 = (do { git fetch origin main --quiet } | complete)
    if $f2.exit_code != 0 { fail $"seed-ensure: refetch: ($f2.stderr | str trim | str substring 0..200)" }
    let co2 = (do { git checkout main --quiet } | complete)
    if $co2.exit_code != 0 { fail $"seed-ensure: back to main: ($co2.stderr | str trim | str substring 0..200)" }
    let reset2 = (do { git reset --hard origin/main --quiet } | complete)
    if $reset2.exit_code != 0 { fail $"seed-ensure: resync main to origin: ($reset2.stderr | str trim | str substring 0..200)" }
    let _ = (do { git branch -D $branch } | complete)
    print $"== workbench: canonical seed ensured — fabro-test-9001 re-pinned, landed via PR ($pr_url)"
}

# Single probe run — no board clean, no mini integration.
#   nu scripts/workbench.nu probe probe-06-guards
#   nu scripts/workbench.nu probe probe-01-schema --expect succeeded
# Default expect comes from PROBES (unknown names default to 'succeeded',
# so `probe mini` runs the seed loop WITHOUT publish). Exit 1 on red.
# Known-red regressions (seed filed): probe-03-tools (fabro-1a41),
# probe-06-guards (fabro-51ad) — a red exit there is the expected finding.
def "main probe" [name: string, --expect: string]: nothing -> nothing {
    assert-local-server
    let known = ($PROBES | where name == $name)
    let exp = if $expect != null { $expect } else if ($known | is-empty) { 'succeeded' } else { $known | first | get expect }
    let bench_id = ('single-' + (date now | format date '%m%d-%H%M%S'))
    print $"== probe: ($name) expect=($exp) label bench=($bench_id)"
    let row = (probe-run $name $exp $bench_id)
    print ($row | table --index false)
    if not $row.ok {
        if $name in ['probe-03-tools' 'probe-06-guards'] {
            print -e 'probe red — KNOWN regression (fabro-1a41 / fabro-51ad), see FACETS.md'
        }
        exit 1
    }
}

def main [] {
    assert-local-server
    clean-runs
    let bench_id = (date now | format date '%m%d-%H%M%S')
    print $"== workbench: bench=($bench_id)"
    # f1a9 world: the scratch automation create needs a registered project
    project-ensure
    # facet 10's notification route must exist BEFORE any run completes
    route-ensure
    print '== workbench: platform checks'
    let prows = (platform-checks)
    print ($prows | table --index false)

    let probes = $PROBES
    print $"== workbench: ($probes | length) probes — label bench=($bench_id)"
    mut rows = []
    for p in $probes {
        print $"-- ($p.name)"
        $rows = ($rows | append (probe-run $p.name $p.expect $bench_id))
    }

    print '== workbench: mini integration (seed loop + publish)'
    seed-ensure
    # mini needs the toolchain env since the loop assets are nu and the
    # closeout is fail-closed on the seeds CLI (seeds-e160): test-local's
    # buildpack image ships neither.
    ensure-sync
    let mini = (do { ^$FABRO create mini --label $"bench=($bench_id)" --environment toolchain --json --server (server) } | complete)
    if $mini.exit_code != 0 { fail $"mini create: ($mini.stderr)" }
    let mini_id = ($mini.stdout | from json | get -o run_id)
    let _ = (do { ^$FABRO start $mini_id --server (server) } | complete)
    let mw = (do { ^$FABRO wait $mini_id --json --server (server) } | complete)
    let mini_ok = ($mw.stdout | from json | get -o status | default 'failed') == 'succeeded'
    $rows = ($rows | append {facet: '09 mini seed loop', ok: $mini_ok, detail: $"run ($mini_id)"})
    if $mini_ok {
        # the mini stream exceeds 1000 events — walk pages (the notification
        # rides at the very end, after the stage journals; bench 0928-205934
        # counted 0 against a real notification.sent at event ~2900)
        mut evs = []
        mut after = 0
        for _ in 1..12 {
            let page = (http get --headers (auth-header) $"((server))/api/v1/runs/($mini_id)/events?limit=1000&after=($after)" | get -o data | default [])
            if ($page | is-empty) { break }
            $after = ($page | last | get stream_seq)
            $evs = ($evs | append $page)
        }
        # The notification append rides a sub-second race past the
        # walk's window (observed bench 1031: terminal seq 353 walked,
        # notification.sent seq 354 landed milliseconds later — the
        # event IS in the stream, the count raced it). Poll briefly
        # before declaring the facet red; the durable property is the
        # record, not the instant.
        mut notif = ($evs | where {|e| (($e | get -o item.record.kind | default '') == 'notification.sent')} | length)
        mut polls = 0
        while $notif == 0 and $polls < 5 {
            sleep 2sec
            $polls = ($polls + 1)
            let tail = (http get --headers (auth-header) $"((server))/api/v1/runs/($mini_id)/events?limit=1000&after=($after)" | get -o data | default [])
            if ($tail | is-not-empty) {
                $after = ($tail | last | get stream_seq)
                $evs = ($evs | append $tail)
            }
            $notif = ($evs | where {|e| (($e | get -o item.record.kind | default '') == 'notification.sent')} | length)
        }
        $rows = ($rows | append {facet: '10 slack notification', ok: ($notif > 0), detail: $"notification.sent=($notif) polls=($polls)"})
        # 09 publish (work#1049 rework): the ENGINE publish is live — the
        # platform creates the run PR itself (author app/fabro-the-factory,
        # e.g. PR #97 on the mini run 01M61ZKPX). The facet asserts the
        # engine PR directly: exists, app-authored, body is generated prose
        # (the fabro-4c11 line — a skeleton body fails the bench). The
        # manual publish-bridge.nu is the FALLBACK only: driven when no
        # engine PR appears (incident repair, fabro-ac40 legacy), asserting
        # the branch push. Never both — the bridge double-creates and
        # alarms against an existing engine PR (the stale-expectation red
        # this rework replaces; the bridge exiting 1 over "Pull request
        # already exists" was the bench's bug, not the platform's).
        let branch = $"fabro/run/($mini_id)"
        mut engine_pr = null
        for _ in 1..6 {
            let lst = (do { ^gh pr list -R denkhaus/fabro-test --head $branch --state all --json number,author --limit 1 } | complete)
            let hits = (try { $lst.stdout | from json } catch { [] })
            if ($hits | length) > 0 {
                $engine_pr = ($hits | first)
                break
            }
            sleep 5sec
        }
        if $engine_pr != null {
            let num = ($engine_pr | get -o number | default 0)
            let author = ($engine_pr | get -o author | get -o login | default '?')
            let view = (do { ^gh pr view $num -R denkhaus/fabro-test --json body --jq '.body' } | complete)
            let body_len = ($view.stdout | str trim | str length)
            let app_ok = ($author == 'fabro-the-factory')
            let prose_ok = ($body_len >= 120)
            $rows = ($rows | append {facet: '09 publish (engine)', ok: ($app_ok and $prose_ok), detail: $"PR #($num) by ($author), body=($body_len) chars"})
        } else {
            # fallback: no engine PR — the bridge repairs (push the exact
            # final commit as the run branch); assert the branch push
            let bridged = (do { nu scripts/publish-bridge.nu $mini_id } | complete)
            let pushed = (do { git ls-remote origin $"refs/heads/($branch)" } | complete)
            let sha = ($pushed.stdout | str trim)
            $rows = ($rows | append {facet: '09 publish (bridge fallback)', ok: (($sha | is-not-empty)), detail: $"no engine PR; bridge exit=($bridged.exit_code), branch=($sha | str substring 0..12 | default 'none')"})
        }
    }

    print ''
    print $"== workbench: FACET TABLE bench=($bench_id)"
    let all = ($prows | append $rows)
    print ($all | table --index false)
    let red = ($all | where not ok)
    # Known-red facets: tracked regressions (seed filed) — visible, but they
    # do not fail the bench exit until their seeds land.
    #   P1 automation replace keeps on_overlap -> fabro-2093 (web PUT drops it)
    #   probe-15-skills-two-tokens            -> fabro-3fce (skill expansion kills sessions)
    # The publish bridge left this list 2026-10-27: fabro-4c11's fix is live
    # (bench 1027-162117: engine PR #87 body is generated prose, not the
    # skeleton) and its last red was the create-then-read index race the
    # bridge now polls through (publish-bridge.nu). The body assertion is
    # re-armed: a skeleton bridge fails the bench again.
    let known_red: list<string> = ['P1 automation replace keeps on_overlap' 'probe-15-skills-two-tokens']
    let fresh = ($red | where {|r| ($r.facet not-in $known_red)} | length)
    if ($fresh > 0) {
        print -e $"WORKBENCH RED: ($fresh) NEW facet failures"
        # Red-exit hygiene (work#1049): a red bench must not poison the
        # next one — the mini's run PR stays open and
        # backpressureOpenPrCap=1 refuses the next publish (observed:
        # PRs #95/#96 cascading). Close the mini's open PR on the way
        # out; the branch stays as evidence.
        let open = (do { ^gh pr list -R denkhaus/fabro-test --head $"fabro/run/($mini_id)" --state open --json number --limit 1 } | complete)
        let hits = (try { $open.stdout | from json } catch { [] })
        if ($hits | length) > 0 {
            let num = ($hits | first | get number)
            let _ = (do { ^gh pr close $num -R denkhaus/fabro-test --comment 'bench hygiene: red bench closes its mini PR so backpressureOpenPrCap does not refuse the next publish (work#1049)' } | complete)
            print $"== hygiene: closed mini PR #($num) — red-exit"
        }
        exit 1
    }
    if ($red | is-not-empty) {
        print -e $"WORKBENCH YELLOW: ($red | length) known-red facets — tracked seeds: fabro-2093 on_overlap, fabro-3fce probe-15"
    }
    print 'WORKBENCH done — no new failures'
}
