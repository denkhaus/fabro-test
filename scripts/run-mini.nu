#!/usr/bin/env nu
# One mini integration run: create -> start -> wait. Prints the terminal JSON.
# Usage: nu scripts/run-mini.nu [--goal 'text']
def main [goal: string = '', --environment: string = 'test-local'] {
    let server = ($env.FABRO_SERVER? | default 'http://127.0.0.1:32276')
    let fabro = ($env.FABRO_BIN? | default ('~/.fabro/bin/fabro' | path expand))

    let created = if ($goal | is-empty) {
        do { ^$fabro create mini --environment $environment --json --server $server } | complete
    } else {
        do { ^$fabro create mini --goal $goal --environment $environment --json --server $server } | complete
    }
    if $created.exit_code != 0 {
        print -e $created.stderr
        exit 1
    }
    let run_id = ($created.stdout | from json | get -o run_id | default '')
    if ($run_id | is-empty) {
        print -e $"run-mini: create returned no run_id: ($created.stdout | str trim)"
        exit 1
    }
    print $"== run: ($run_id)"

    let started = (do { ^$fabro start $run_id --server $server } | complete)
    if $started.exit_code != 0 {
        print -e $started.stderr
        exit 1
    }
    let waited = (do { ^$fabro wait $run_id --json --server $server } | complete)
    print $waited.stdout
    exit $waited.exit_code
}
