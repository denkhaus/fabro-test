#!/usr/bin/env nu
# Validate every .fabro/workflows/*/workflow.fabro via the fabro CLI
# (full admission; one graph per invocation so one failure hides none).
# path self is parse-time only: the repo root must be a top-level const.
const ROOT = (path self | path dirname | path dirname)

def main [target: string = ''] {
    let fabro = ('~/.fabro/bin/fabro' | path expand)
    # admission-deny probes are invalid ON PURPOSE (fabro-70af root check);
    # their refusal is proven by `just probe probe-11-admission-deny`,
    # not by this validator.
    let graphs = ((try {
        ls $"($ROOT)/.fabro/workflows/*($target)*/workflow.fabro" | get name | sort
    } catch { [] })
    | where {|g| 'admission-deny' not-in $g})
    if ($graphs | is-empty) {
        print 'validate: no workflow graphs found'
        exit 2
    }
    mut failed = 0
    for g in $graphs {
        let r = (do { ^$fabro validate $g } | complete)
        print $r.stdout
        if $r.exit_code != 0 {
            print -e $r.stderr
            $failed = ($failed + 1)
        }
    }
    print $"validate: (($graphs | length) - $failed)/(($graphs | length)) ok"
    if $failed > 0 { exit 1 }
}
