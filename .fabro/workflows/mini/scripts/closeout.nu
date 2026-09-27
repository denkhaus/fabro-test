#!/usr/bin/env nu
# Close exactly this run's seed (id on stdin) through the seeds CLI.
# Tracker mutations go EXCLUSIVELY through the seeds app — never a direct
# file write (operator directive 2026-09-26: a run's hand-written JSONL
# caused format drift and a full-file merge conflict, PR #6 vs PR #7).
# Fails closed when the sandbox has no seeds binary: a red closeout beats
# a silent rule violation.
# ^cat, not `input`: this nu build surfaces piped stdin only
# to externals (`input` fails closed with an I/O error here).
let seed_id = (^cat | str trim)
if ($seed_id | is-empty) {
    print -e "closeout failed: empty seed id on stdin"
    exit 1
}
if ((which seeds | length) == 0) {
    print -e "closeout failed: the seeds CLI is not available in this sandbox (seeds-e160); refusing to write .seeds/issues.jsonl by hand"
    exit 1
}
let res = (do { seeds close $seed_id } | complete)
if ($res.stdout | str trim) != '' {
    print $res.stdout
}
if $res.exit_code != 0 {
    print -e $"closeout failed: seeds close ($seed_id): ($res.stderr | str trim)"
    exit 1
}
print $"closed ($seed_id)"
