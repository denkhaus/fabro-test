#!/usr/bin/env nu
# observation-cli probe (ADR-0039 stage C, denkhaus/work#1107): the
# script-stage door of the observation surface, end to end from inside a
# run sandbox. Asserts every link:
#   1. STAGE SELF-AWARENESS: the engine binds the quartet
#      (FABRO_RUN_ID, FABRO_NODE_ID, FABRO_EXECUTION, FABRO_FIRING)
#      into every command script's environment — the vendored engine
#      change this probe is born with.
#   2. THE CLI DOOR: `fabro observation record` with NO identity flags
#      defaults from that environment, travels the run channel with the
#      run's worker principal, and the server stores the record.
#   3. THE SEQ: the CLI's result names the record's per-run seq (the
#      identity the work-item link seam references).
# The record's LANDING and its stage-card FOLD are asserted by the
# workbench post-check (workbench.nu, probe-37 arm): the fold only holds
# when the env-bound position IS the stage's real position.
#
# Window note: the sandbox `fabro` is the PINNED release binary; until
# the fork.30 window ships the observation verb and pin-toolchain pairs,
# arm 2 fails LOUDLY with the skew named (the probe-35 precedent — a
# version skew must announce itself, never degrade silently).

def fail [what: string]: nothing -> nothing {
    print -e $"observation-cli-probe: ($what)"
    exit 1
}

def main []: nothing -> nothing {
    # 1. the engine-bound quartet (stage self-awareness)
    for name in [FABRO_RUN_ID FABRO_NODE_ID FABRO_EXECUTION FABRO_FIRING] {
        let value = ($env | get -o $name | default '')
        if ($value | is-empty) {
            fail $"($name) is not set — the engine does not bind the stage's identity into command scripts"
        }
        print $"self: ($name)=($value)"
    }
    for name in [FABRO_EXECUTION FABRO_FIRING] {
        if (($env | get $name) | str trim | parse -r '^\d+$' | is-empty) {
            fail $"($name) is not a number: ($env | get $name)"
        }
    }

    # the channel transport the CLI rides (the work verbs' env contract)
    let sock = ($env.FABRO_SERVER? | default '')
    if ($sock | is-empty) { fail 'FABRO_SERVER is not set — the channel mount did not run' }

    # 2. the CLI door: no identity flags — the env defaults carry them
    let bin = ($env.FABRO_BIN? | default 'fabro')
    let res = (do {
        ^$bin observation --server $sock record --category note --text 'probe-37 recorded from a script stage'
    } | complete)
    if ($res.stderr | str contains 'unrecognized subcommand') {
        fail $"the sandbox CLI predates the observation verb — pin the fork.30 toolchain after its window (the probe-35 skew class): ($res.stderr | str trim | str substring 0..200)"
    }
    if $res.exit_code != 0 {
        print -e ($res.stderr | str trim | str substring 0..400)
        fail 'observation record through the channel failed (rc != 0)'
    }

    # 3. the seq in the result
    if not ($res.stdout | str contains 'recorded at seq') {
        fail $"the result must name the record's seq: ($res.stdout | str trim)"
    }
    print $"cli: ($res.stdout | str trim)"
    print 'observation-cli-probe: all links green'
}
