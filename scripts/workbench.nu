#!/usr/bin/env nu
# THE workbench: pre-clean the board, then all probes + platform checks
# + mini integration with publish. Every run carries label bench=<id>.
# Rot/Gruen-Tabelle pro Facette; rot -> exit 1.

# Runplace-agnostic: the server comes from FABRO_SERVER (same convention
# as run-mini.nu); unset defaults to the local dev stack.
def server []: nothing -> string { $env.FABRO_SERVER? | default 'http://127.0.0.1:32276' }
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
        let created = (http post --headers (auth-header) -t 'application/json'
            $"((server))/api/v1/automations"
            ({id: 'bench-on-overlap-probe', name: 'bench-on-overlap-probe', environment_id: 'toolchain',
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
    $rows
}

def probe-run [name: string, expect: string, bench_id: string]: nothing -> record {
    let t0 = (date now)
    # probe scripts execute nu in the sandbox — test-local (buildpack-deps)
    # ships no nushell; the toolchain env has nu via mise shims.
    let created = (do { ^$FABRO create $name --label $"bench=($bench_id)" --environment toolchain --json --server (server) } | complete)
    if $created.exit_code != 0 {
        let msg = ($created.stderr | str trim)
        # expect 'refused': admission must REJECT the graph and say why
        # (fabro-70af: unknown x.* -> fork.x_attribute_known).
        if $expect == 'refused' {
            let named = ($msg | str contains 'x_attribute_known') or ($msg | str contains 'unknown attribute')
            return {facet: $name, ok: $named, detail: ($msg | str substring 0..140)}
        }
        return {facet: $name, ok: false, detail: ($msg | str substring 0..140)}
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
    {facet: $name, ok: $ok, detail: $detail}
}

# The mini loop runs THE canonical bench seed: fixed wording, fixed prestate.
# Before every bench: reset bench/canonical.nu + tests to the tracked stub,
# then ensure the seed row is open with the exact same text — runs stay
# comparable across benches and upstream merges (user directive).
# ALL tracker mutations go through the seeds app, never manual JSON edits.
def seed-ensure []: nothing -> nothing {
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
    let upd = (do { ^mise exec -- seeds update fabro-test-9001 --status open --title 'Implement canonical_mark in bench/canonical.nu' --description $desc } | complete)
    if $upd.exit_code != 0 {
        fail $"seed-ensure: cannot re-pin fabro-test-9001: ($upd.stderr | str trim | str substring 0..200) — restore the row from git history (fixed id; seeds create cannot mint it)"
    }
    # (c) commit + push the deterministic prestate
    let _ = (do { git add bench/canonical.nu tests/test-canonical.nu .seeds/issues.jsonl } | complete)
    let _ = (do { git -c user.name=denkhaus -c user.email=denkhaus@users.noreply.github.com commit -m 'bench: reset canonical prestate + reopen seed fabro-test-9001' --quiet } | complete)
    let _ = (do { git push --quiet } | complete)
    print '== workbench: canonical seed ensured (fabro-test-9001, fixed wording)'
}

# Single probe run — no board clean, no mini integration.
#   nu scripts/workbench.nu probe probe-06-guards
#   nu scripts/workbench.nu probe probe-01-schema --expect succeeded
# Default expect comes from PROBES (unknown names default to 'succeeded',
# so `probe mini` runs the seed loop WITHOUT publish). Exit 1 on red.
# Known-red regressions (seed filed): probe-03-tools (fabro-1a41),
# probe-06-guards (fabro-51ad) — a red exit there is the expected finding.
def "main probe" [name: string, --expect: string]: nothing -> nothing {
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
    clean-runs
    let bench_id = (date now | format date '%m%d-%H%M%S')
    print $"== workbench: bench=($bench_id)"
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
    let mini = (do { ^$FABRO create mini --label $"bench=($bench_id)" --environment toolchain --json --server (server) } | complete)
    if $mini.exit_code != 0 { fail $"mini create: ($mini.stderr)" }
    let mini_id = ($mini.stdout | from json | get -o run_id)
    let _ = (do { ^$FABRO start $mini_id --server (server) } | complete)
    let mw = (do { ^$FABRO wait $mini_id --json --server (server) } | complete)
    let mini_ok = ($mw.stdout | from json | get -o status | default 'failed') == 'succeeded'
    $rows = ($rows | append {facet: '09 mini seed loop', ok: $mini_ok, detail: $"run ($mini_id)"})
    if $mini_ok {
        let evs = (http get --headers (auth-header) $"((server))/api/v1/runs/($mini_id)/events?limit=1000" | get -o data | default [])
        let notif = ($evs | where {|e| (($e | get -o item.record.kind | default '') == 'notification.sent')} | length)
        $rows = ($rows | append {facet: '10 slack notification', ok: ($notif > 0), detail: $"notification.sent=($notif)"})
        let pub = (do { nu scripts/publish-bridge.nu $mini_id } | complete)
        $rows = ($rows | append {facet: '09 publish bridge', ok: ($pub.exit_code == 0), detail: ($pub.stdout | lines | last | default ($pub.stderr | str substring 0..120))})
    }

    print ''
    print $"== workbench: FACET TABLE bench=($bench_id)"
    let all = ($prows | append $rows)
    print ($all | table --index false)
    let red = ($all | where not ok)
    # Known-red facets: tracked regressions (seed filed) — visible, but they
    # do not fail the bench exit until their seeds land. fabro-1a41 and
    # fabro-51ad landed 2026-09-26; the list is empty until a new tracked
    # regression goes red.
    let known_red: list<string> = []
    let fresh = ($red | where {|r| ($r.facet not-in $known_red)} | length)
    if ($fresh > 0) {
        print -e $"WORKBENCH RED: ($fresh) NEW facet failures"
        exit 1
    }
    if ($red | is-not-empty) {
        print -e $"WORKBENCH YELLOW: ($red | length) known-red facets — tracked seeds (fabro-1a41, guards investigation)"
    }
    print 'WORKBENCH done — no new failures'
}
