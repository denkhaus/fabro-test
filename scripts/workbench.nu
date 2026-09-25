#!/usr/bin/env nu
# THE workbench: all probes + platform checks + mini integration + publish.
# Rot/Gruen-Tabelle pro Facette; rot -> exit 1. Budget: < 15 min, < 1 EUR.

const SERVER = 'http://127.0.0.1:32276'
const FABRO = ('~/.fabro/bin/fabro' | path expand)

def auth-header []: nothing -> record {
    let token = (open ~/.fabro/auth.json | get servers | get -o $SERVER | get -o token | default '')
    { Authorization: $"Bearer ($token)" }
}

def fail [msg: string]: nothing -> nothing {
    print -e $"╔══ WORKBENCH ALARM: ($msg) ══╗"
    exit 1
}

# -- platform checks ------------------------------------------------------
def platform-checks []: nothing -> list<record> {
    mut rows = []
    let health = (http get $"($SERVER)/health")
    $rows = ($rows | append {facet: 'P1 health', ok: ($health.status? == 'ok'), detail: ($health | to json -r)})
    let models = (http get --headers (auth-header) $"($SERVER)/api/v1/models?provider=zai&limit=5" | get -o data | default [])
    let glm = ($models | where id == glm-4.7 | select -o 0)
    $rows = ($rows | append {facet: 'P1 zai glm-4.7 configured', ok: (($glm | length) > 0 and ($glm | first | get -o configured | default false)), detail: ''})
    let envs = (http get --headers (auth-header) $"($SERVER)/api/v1/environments" | get data | get id)
    $rows = ($rows | append {facet: 'P1 env test-local', ok: ($envs | any {|e| $e == 'test-local'}), detail: ($envs | str join ',')})
    let index = (http get $"($SERVER)/" | str contains '<html')
    $rows = ($rows | append {facet: 'P2 SPA index', ok: $index, detail: ''})
    $rows
}

    # Answer every pending HITL question by kind until the run leaves the gate.
    def hitl-answer [run_id: string]: nothing -> bool {
        for _ in 1..120 {
            let qs = (http get --headers (auth-header) $"($SERVER)/api/v1/runs/($run_id)/questions" | get -o data | default [])
            let pending = ($qs | where {|q| (($q | get -o status | default 'pending') == 'pending')})
            if ($pending | is-empty) {
                let run = (http get --headers (auth-header) $"($SERVER)/api/v1/runs/($run_id)")
                let st = ($run | get -o lifecycle | get -o status | get -o kind | default '')
                if $st in ['succeeded' 'failed'] { return true }
                sleep 2sec
                continue
            }
            let q = ($pending | first)
            let qid = ($q | get -o id | default '')
            let kind = ($q | get -o question_type | default ($q | get -o kind | default ''))
            if ($qid | is-empty) { return false }
            let opts = ($q | get -o options | default [] | get -o option_key | default [])
            let body = if $kind in ['yes_no' 'confirmation'] {
                '{"kind": "yes"}'
            } else if $kind == 'multiple_choice' {
                if ($opts | is-empty) { '{"kind": "selected", "option_key": "G"}' } else {
                    ({ kind: 'selected', option_key: ($opts | first) } | to json -r)
                }
            } else if $kind == 'multi_select' {
                if ($opts | is-empty) { '{"kind": "multi_selected", "option_keys": ["G"]}' } else {
                    ({ kind: 'multi_selected', option_keys: [($opts | first)] } | to json -r)
                }
            } else {
                '{"kind": "text", "text": "workbench auto-answer"}'
            }
            let _ = (try {
                http post --headers (auth-header) -t 'application/json' $"($SERVER)/api/v1/runs/($run_id)/questions/($qid)/answer" $body
            } catch { null })
            sleep 1sec
        }
        false
    }

    # -- one probe run (helper above) ----------------------------------------
    def probe-run [name: string, expect: string]: nothing -> record {
    let t0 = (date now)
    let created = (do { ^$FABRO create $name --environment test-local --json --server $SERVER } | complete)
    if $created.exit_code != 0 {
        return {facet: $name, ok: false, detail: ($created.stderr | str trim | str substring 0..140)}
    }
    let run_id = ($created.stdout | from json | get -o run_id | default '')
    if ($run_id | is-empty) { return {facet: $name, ok: false, detail: 'no run_id'} }
    let started = (do { ^$FABRO start $run_id --server $SERVER } | complete)
    if $started.exit_code != 0 {
        return {facet: $name, ok: false, detail: ($started.stderr | str trim | str substring 0..140)}
    }

    # interview probe: answer the pending yes_no question via API
    if $name == 'probe-08-interview' {
        mut answered = false
        for _ in 1..60 {
            let run = (http get --headers (auth-header) $"($SERVER)/api/v1/runs/($run_id)")
            let q = ($run | get -o current_question | default null)
            if $q != null {
                let qid = ($run | get -o current_question | get -o question | get -o id | get -o 0 | default ($q | get -o id | default ''))
                if ($qid | is-empty) { break }
                let post = (try {
                    http post --headers (auth-header) -t 'application/json' $"($SERVER)/api/v1/runs/($run_id)/questions/($qid)/answer" '{"kind": "yes"}'
                } catch { null })
                $answered = ($post != null)
                break
            }
            sleep 2sec
        }
        if not $answered { return {facet: $name, ok: false, detail: 'question not answered'} }
    }

    let waited = (do { ^$FABRO wait $run_id --json --server $SERVER } | complete)
    let info = (try { $waited.stdout | from json } catch { null })
    if $info == null { return {facet: $name, ok: false, detail: 'no terminal json'} }
    let status = ($info | get -o status | default '?')
    let secs = ((((date now) - $t0) | into int) / 1_000_000_000)

    let ok = if $expect == 'succeeded' { $status == 'succeeded' } else { $status == 'failed' }
    let detail = if $ok { $"($status) in ($secs)s" } else { $"expected ($expect), got ($status): ($info | get -o reason | default '?')" }

    # extra assertions
    if $ok and $name == 'probe-04-runtools' {
        # child run must exist and be terminal
        let children = (http get --headers (auth-header) $"($SERVER)/api/v1/runs?limit=10" | get data | where {|r| (($r | get -o parent_id | default '') == $run_id)})
        let child_ok = ($children | length) > 0
        return {facet: $name, ok: $child_ok, detail: ($detail + $" | children=($children | length)" )}
    }
    if $ok and $name == 'probe-07-artifacts' {
        let evs = (http get --headers (auth-header) $"($SERVER)/api/v1/runs/($run_id)/events?limit=1000" | get -o data | default [])
        let collected = ($evs | where {|e| (($e | get -o item.record.kind | default '') == 'artifact.collected')} | length)
        return {facet: $name, ok: ($collected > 0), detail: ($detail + $" | artifact.collected=($collected)" )}
    }
    if $ok and $name == 'probe-06-guards' {
        let evs = (http get --headers (auth-header) $"($SERVER)/api/v1/runs/($run_id)/events?limit=1000" | get -o data | default [])
        let life = ($evs | where {|e| (($e | get -o item.record.kind | default '') == 'run.lifecycle')} | get -o item.record.transition)
        let deadlocked = ($life | last | default '' | str lowercase | str contains 'deadlock')
        return {facet: $name, ok: $deadlocked, detail: ($detail + ' deadlock-lifecycle=' + ($deadlocked | into string)) }
    }
    {facet: $name, ok: $ok, detail: $detail}
}

def main [] {
    print '== workbench: platform checks'
    let prows = (platform-checks)
    print ($prows | table --index false)

    let probes = [
        [name expect];
        [probe-01-schema succeeded]
        [probe-02-envelope succeeded]
        [probe-03-tools succeeded]
        [probe-04-runtools succeeded]
        [probe-05-hooks succeeded]
        [probe-06-guards failed]
        [probe-07-artifacts succeeded]
        [probe-08-interview succeeded]
    ]
    print $"== workbench: ($probes | length) probes"
    mut rows = []
    for p in $probes {
        print $"-- ($p.name)"
        $rows = ($rows | append (probe-run $p.name $p.expect))
    }

    print '== workbench: mini integration (seed loop + publish)'
    let mini = (do { ^$FABRO create mini --environment test-local --json --server $SERVER } | complete)
    if $mini.exit_code != 0 { fail $"mini create: ($mini.stderr)" }
    let mini_id = ($mini.stdout | from json | get -o run_id)
    let _ = (do { ^$FABRO start $mini_id --server $SERVER } | complete)
    let mw = (do { ^$FABRO wait $mini_id --json --server $SERVER } | complete)
    let mini_ok = ($mw.stdout | from json | get -o status | default 'failed') == 'succeeded'
    $rows = ($rows | append {facet: '09 mini seed loop', ok: $mini_ok, detail: $"run ($mini_id)"})
    if $mini_ok {
        let pub = (do { nu scripts/publish-bridge.nu $mini_id } | complete)
        $rows = ($rows | append {facet: '09 publish bridge', ok: ($pub.exit_code == 0), detail: ($pub.stdout | lines | last | default '')})
    }

    print ''
    print '== workbench: FACET TABLE'
    let all = ($prows | append $rows)
    print ($all | table --index false)
    let red = ($all | where not ok)
    if ($red | is-not-empty) {
        print -e $"WORKBENCH RED: ($red | length) facets failed"
        exit 1
    }
    print 'WORKBENCH GREEN — deploy-ready'
}
