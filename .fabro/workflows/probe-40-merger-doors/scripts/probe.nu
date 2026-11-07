#!/usr/bin/env nu
# probe-40 (ADR-0039 stage E, denkhaus/work#1107): the merger's doors
# over the run channel, against the live server.
#
#   1. THE MERGE DOOR'S AUTHZ: THIS probe run's workflow is not the
#      merger, so `run merge <run-id>` must REFUSE with the allowlist
#      teaching (403, the workflow-allowlist message). A probe cannot
#      fire a happy merge — that is the merger workflow's own pass; the
#      refusal proves the door is alive, authorizing, and teaching.
#   2. THE SETTLED-VERDICT QUEUE READ: `run queue --field closable
#      --verdict enabled` (the closing pass's worklist read) exits 0
#      with the `data` record shape the closing pass parses.
#   3. GRAMMAR: the verdict filter refuses a bogus value teaching the
#      two settled verdicts; pending/parked are refused as filter
#      values (they ARE the default queue).
#
# RED until the fork.30 toolchain pin ships the merge verb and the
# verdict filter (rows 35/37/39 skew precedent): until that window a
# clap parse failure is the loud, named skew signal.

const RECORD_KEYS = ['data']

def fail [what: string]: nothing -> nothing {
    print -e $"merger-doors-probe: ($what)"
    exit 1
}

def door [argv: list<string>]: nothing -> any {
    let bin = ($env.FABRO_BIN? | default 'fabro')
    (do { ^$bin ...$argv } | complete)
}

def main []: nothing -> nothing {
    let sock = ($env.FABRO_SERVER? | default '')
    if ($sock | is-empty) { fail 'FABRO_SERVER is not set — the channel mount did not run' }

    # 1. the merge door's authz refusal for a non-merger workflow run
    #    (this probe). The target run id is syntactically valid; the
    #    door refuses on the WORKFLOW allowlist before anything else.
    let merge = (door [run 'merge' '01M5844J1FDDPR0BE000000000' '--server' $sock])
    if $merge.exit_code == 0 {
        fail 'a non-merger workflow run must NOT merge — the door refused nothing'
    }
    if not ($merge.stderr | str contains 'merger') {
        fail $"the merge refusal must teach the merger allowlist: ($merge.stderr | str trim | str substring 0..240)"
    }
    print 'merge door: the non-merger refusal teaches the allowlist'

    # 2. the settled-verdict queue read (the closing pass's worklist)
    let queue = (door [run 'queue' '--field' 'closable' '--verdict' 'enabled' '--workflow' 'develop' '--json' '--server' $sock])
    if $queue.exit_code != 0 {
        print -e ($queue.stderr | str trim | str substring 0..400)
        fail 'the verdict-flipped queue read through the channel failed (rc != 0)'
    }
    let parsed = (try { $queue.stdout | from json } catch { null })
    if ($parsed | describe | str starts-with "record") {
        if ($parsed | get -o data) == null {
            fail $"the queue record lost its data key: ($queue.stdout | str trim | str substring 0..240)"
        }
        print $"queue: ($parsed.data | length) run\(s\) settled on closable=enabled"
    } else {
        fail $"the queue must print the record the closing pass parses: ($queue.stdout | str trim | str substring 0..240)"
    }

    # 3. grammar: a bogus verdict teaches the settled values; pending is
    #    the default queue, never a filter.
    let bogus = (door [run 'queue' '--verdict' 'bogus' '--server' $sock])
    if $bogus.exit_code == 0 { fail 'a bogus --verdict must refuse, not succeed' }
    if not ($bogus.stderr | str contains 'enabled') {
        fail $"the verdict refusal must teach the settled values: ($bogus.stderr | str trim | str substring 0..240)"
    }
    let pending = (door [run 'queue' '--verdict' 'pending' '--server' $sock])
    if $pending.exit_code == 0 { fail 'pending must refuse as a filter value — it IS the default queue' }

    print 'probe-40: ok — merge authz teaching, verdict-flipped record shape, grammar refusals'
}
