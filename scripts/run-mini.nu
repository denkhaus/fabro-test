#!/usr/bin/env nu
# One mini integration run: create -> start -> wait. Prints the terminal JSON.
# Usage: nu scripts/run-mini.nu [--goal 'text']
# Lifecycle pieces from the bench adapter library (scripts/lib/bench.nu);
# the pieces keep the early run-id print (create -> print -> start -> wait).
use lib/bench.nu *

def main [goal: string = '', --environment: string = 'toolchain'] {
    let create_args = (if ($goal | is-empty) {
        ['create' 'mini' '--environment' $environment '--json' '--server' (server)]
    } else {
        ['create' 'mini' '--goal' $goal '--environment' $environment '--json' '--server' (server)]
    })
    let created = (run-create $create_args --what 'run-mini')
    if $created.exit_code != 0 {
        print -e $created.stderr
        exit 1
    }
    if ($created.run_id | is-empty) {
        print -e $"run-mini: create returned no run_id: ($created.stdout | str trim)"
        exit 1
    }
    print $"== run: ($created.run_id)"
    let started = (run-start $created.run_id)
    if $started.exit_code != 0 {
        print -e $started.stderr
        exit 1
    }
    let waited = (run-wait $created.run_id)
    print $waited.stdout
    exit $waited.exit_code
}
