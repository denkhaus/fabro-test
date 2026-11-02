#!/usr/bin/env nu
# adjudicator-reads probe (ADR-0039 stage D part 2, denkhaus/work#1107):
# the adjudicator's four READ doors, end to end from inside a run
# sandbox over the channel. Door symmetry is the facet: the SAME argv
# the fast-path script drives (pinned equal to the fabro repo's
# work-channel builders by the lane-commons battery), against the LIVE
# server, with the JSON RECORD shapes the fast path parses:
#   1. QUEUE: `run queue --field merge --workflow develop --json`
#      exits 0 and stdout is the {data, meta} record — the fast path's
#      entries-from reads .data.
#   2. FACTS: `observation list --run-id $FABRO_RUN_ID --json` exits 0
#      and stdout is the {observations} record — the shape this probe
#      family was born against: the CLI once printed a bare array,
#      which the fast path silently reads as ZERO facts (every run
#      would look painpoint-free).
#   3. RADIUS: `work radius --project fabro-proof <key> --json` exits 0
#      and stdout is the {item, radius} record.
#   4. ANSWER CHANNEL: `work comments --project fabro-proof <key> --json`
#      exits 0 and stdout is the {comments} record — the door a parked
#      run's fork travels back on.
# Grammar legs (client-side, deterministic): `--field bogus` refuses
# teaching the two fields; `--run-id nope` refuses naming the run id.
# The radius/comments target comes from `work list` (probe-31's proven
# call shape); proof-ensure keeps the proof items open at bench time.
#
# Window note: the sandbox `fabro` is the PINNED toolchain binary;
# until the fork.30 window ships the read verbs, every leg fails LOUDLY
# with the skew named (the probe-35/37 precedent — a version skew
# announces itself, never degrades silently).

const SCOPED_PROJECT = 'fabro-proof'

def fail [what: string]: nothing -> nothing {
    print -e $"adjudicator-reads-probe: ($what)"
    exit 1
}

# One door call, complete-wrapped. A clap reject of a verb or flag that
# must exist is the version-skew class: fail loudly naming it, so a red
# probe reads as "pin the toolchain", never as a transport mystery.
def door [argv: list<string>]: nothing -> any {
    let bin = ($env.FABRO_BIN? | default 'fabro')
    let res = (do { ^$bin ...$argv } | complete)
    let err = ($res.stderr | str trim)
    let skew = ($err | str contains 'unrecognized subcommand') or ($err | str contains 'unexpected argument')
    if $skew and $res.exit_code != 0 {
        fail $"the pinned CLI predates the adjudicator read doors — pin the fork.30 toolchain after its window (the probe-35/37 skew class): ($err | str substring 0..240)"
    }
    $res
}

# A door's stdout must be a JSON record carrying `key` — the silent
# shape drift this probe exists to catch reads as an empty list
# everywhere else, so it fails HERE with the shape named.
def record-of [stdout: string, key: string, name: string]: nothing -> any {
    let parsed = (try { $stdout | from json } catch { null })
    if not ($parsed | describe | str starts-with 'record') {
        fail $"($name) stdout is not a JSON record: ($parsed | describe) — ($stdout | str trim | str substring 0..240)"
    }
    if ($parsed | get -o $key) == null {
        fail $"($name) record lost its `($key)` key: ($stdout | str trim | str substring 0..240)"
    }
    $parsed
}

def main []: nothing -> nothing {
    let sock = ($env.FABRO_SERVER? | default '')
    if ($sock | is-empty) { fail 'FABRO_SERVER is not set — the channel mount did not run' }
    let rid = ($env.FABRO_RUN_ID? | default '')
    if ($rid | is-empty) { fail 'FABRO_RUN_ID is not set — the engine did not bind the stage identity (probe-37 quartet)' }

    # 1. the queue door (the fast path's worklist read)
    let queue = (door ['run' 'queue' '--field' 'merge' '--workflow' 'develop' '--json' '--server' $sock])
    if $queue.exit_code != 0 {
        print -e ($queue.stderr | str trim | str substring 0..400)
        fail 'run queue through the channel failed (rc != 0)'
    }
    let queue_record = (record-of $queue.stdout 'data' 'run queue')
    print $"queue: ($queue_record.data | length) run(s) queued on merge/develop"

    # grammar: a bogus field refuses teaching the two fields
    let refused = (door ['run' 'queue' '--field' 'bogus' '--json' '--server' $sock])
    if $refused.exit_code == 0 { fail 'a bogus --field must refuse, not succeed' }
    if not ($refused.stderr | str contains 'not an orchestration field') {
        fail $"the field refusal must teach the fields: ($refused.stderr | str trim | str substring 0..240)"
    }

    # 2. the facts door — THIS run's records (empty is valid; the
    # record shape is the assertion)
    let facts = (door ['observation' '--server' $sock 'list' '--run-id' $rid '--json'])
    if $facts.exit_code != 0 {
        print -e ($facts.stderr | str trim | str substring 0..400)
        fail 'observation list through the channel failed (rc != 0)'
    }
    let facts_record = (record-of $facts.stdout 'observations' 'observation list')
    print $"facts: ($facts_record.observations | length) observation record(s) on this run"

    # grammar: a non-run-id refuses naming the run id
    let bad_rid = (door ['observation' '--server' $sock 'list' '--run-id' 'nope' '--json'])
    if $bad_rid.exit_code == 0 { fail 'a non-run-id must refuse, not succeed' }
    if not ($bad_rid.stderr | str contains 'is not a run id') {
        fail $"the run-id refusal must name the id: ($bad_rid.stderr | str trim | str substring 0..240)"
    }

    # the radius/comments target: the proof project's first open item
    # (probe-31's proven call shape; proof-ensure keeps items open)
    let bin = ($env.FABRO_BIN? | default 'fabro')
    let listed = (do { ^$bin work --server $sock list --project $SCOPED_PROJECT --limit 1 --json } | complete)
    if $listed.exit_code != 0 {
        print -e ($listed.stderr | str trim | str substring 0..400)
        fail 'work list through the channel failed (rc != 0)'
    }
    let items = (try { $listed.stdout | from json } catch { [] })
    if ($items | is-empty) {
        fail $"project ($SCOPED_PROJECT) holds no open item for the radius/comments legs — proof-ensure must run before this probe"
    }
    let key = ($items | get 0.itemKey)

    # 3. the radius door (the closure radius a verdict hinges on)
    let radius = (door ['work' '--server' $sock 'radius' '--project' $SCOPED_PROJECT $key '--json'])
    if $radius.exit_code != 0 {
        print -e ($radius.stderr | str trim | str substring 0..400)
        fail $"work radius through the channel failed for ($key) (rc != 0)"
    }
    let radius_record = (record-of $radius.stdout 'radius' 'work radius')
    print $"radius: ($key) holds ($radius_record.radius | length) open item(s)"

    # 4. the answer channel (a parked run's fork travels back here)
    let comments = (door ['work' '--server' $sock 'comments' '--project' $SCOPED_PROJECT $key '--json'])
    if $comments.exit_code != 0 {
        print -e ($comments.stderr | str trim | str substring 0..400)
        fail $"work comments through the channel failed for ($key) (rc != 0)"
    }
    let comments_record = (record-of $comments.stdout 'comments' 'work comments')
    print $"comments: ($comments_record.comments | length) comment(s) on ($key)"

    print 'adjudicator-reads-probe: all four doors green'
}
