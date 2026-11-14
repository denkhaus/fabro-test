#!/usr/bin/env nu
# Setup for the USER's manual retry-latest click (work#1320): one failed
# specimen run on the board (the click target), one newer green run of
# the FIXED version — the no-id resolution needs a newer run of the slug
# naming the fixed version. Leaves BOTH runs on the board; the
# retry-latest click itself is the user's, never this script's.
#
#   FABRO_SERVER=http://127.0.0.1:32276 nu scripts/setup-user-retry-lab.nu

def server []: nothing -> string { $env.FABRO_SERVER? | default 'http://127.0.0.1:32276' }

def auth-header []: nothing -> record {
    let s = (open ~/.fabro/auth.json | get servers | get -o (server))
    let token = ($s | get -o token | default ($s | get -o access_token | default ''))
    { Authorization: $"Bearer ($token)" }
}

const FABRO = ('~/.fabro/bin/fabro' | path expand)

source retry-latest-facet.nu

def status-of [run: string]: nothing -> string {
    ^$FABRO ps -a --json --server (server) | from json | where run_id == $run | get 0.status.kind
}

def main []: nothing -> nothing {
    let tag = (date now | format date '%m%d-%H%M%S')

    # The failed specimen: the click target.
    let faulty_id = (facet-register-version (facet-graph "exit 1"))
    let failed_run = (facet-run-from-version $faulty_id $"user-lab-($tag)")
    let failed_status = (status-of $failed_run)
    print $"failed specimen: ($failed_run) status=($failed_status) version=($faulty_id)"
    if $failed_status != 'failed' {
        error make {msg: $"specimen did not fail as expected: ($failed_status)"}
    }

    # The newer green run of the FIXED version (the line kept running).
    let fixed_id = (facet-register-version (facet-graph "echo check-green"))
    let green_run = (facet-run-from-version $fixed_id $"user-lab-($tag)")
    let green_status = (status-of $green_run)
    print $"green run:        ($green_run) status=($green_status) version=($fixed_id)"

    print ""
    print $"CLICK TARGET: ((server))/runs/($failed_run)"
}
