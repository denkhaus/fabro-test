#!/usr/bin/env nu
# Evidence capture: run-scoped diff + commits + worktree state.
# Diff base = parent of THIS run's oldest checkpoint commit (subject
# 'fabro(<run-id>):'), like develop's evidence.nu — no origin refs needed.
# Fallback base = HEAD (grounded:false) instead of failing: a capture must
# never strand the run (soft-exit path costs a full re-cycle).
def gitsh [args: list<string>] {
    # The engine prepares /workspace as a different UID than the run
    # user; every git call needs the ownership exemption or git exits
    # 128 with "detected dubious ownership".
    let r = (do { ^git -c safe.directory=* ...$args } | complete)
    if $r.exit_code != 0 {
        print -e $"evidence: git ($args | first 2 | str join ' ') failed: ($r.stderr | str trim)"
        exit 1
    }
    $r.stdout
}

let branch = (gitsh [rev-parse --abbrev-ref HEAD] | str trim)
let parsed = ($branch | parse --regex '^fabro/run/(?<id>[^/]+)$')
let run_id = (if ($parsed | is-empty) { '' } else { $parsed | get id | first })

let info = (if ($run_id | is-empty) {
    {base: 'HEAD', grounded: false}
} else {
    let mark = $"fabro\(($run_id)\):"
    let checkpoints = (gitsh [log --format=%H --fixed-strings --grep $mark] | lines | where {|l| ($l | str trim) != ''})
    if ($checkpoints | is-empty) {
        {base: 'HEAD', grounded: false}
    } else {
        {base: (gitsh [rev-parse $"($checkpoints | last)^"] | str trim), grounded: true}
    }
})

let short = (gitsh [rev-parse --short $info.base] | str trim)
let suffix = (if $info.grounded { '' } else { ' UNGROUNDED-fallback' })
print ("== evidence (base " + $short + $suffix + ") ==")
print "-- diff (committed seed work) --"
print (gitsh [--no-pager diff $info.base])
print "-- commits --"
print (gitsh [--no-pager log --oneline $"($info.base)..HEAD"])
print "-- worktree status --"
print (gitsh [--no-pager status --porcelain])
