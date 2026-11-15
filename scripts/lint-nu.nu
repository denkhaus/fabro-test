#!/usr/bin/env nu
# Parse-check every nu script in the repo. nu-check is the authority:
# `nu --ide-check` (what the bench workflow used before sprint 89) exits
# 0 even on a parse-broken file — the CI gate never gated anything
# (found by the work#1320 session retro's deliberate red arm). This
# script also replaces that loop in the workflow.

const PATTERNS = ['bench/*.nu' 'tests/*.nu' 'scripts/*.nu' '.fabro/workflows/*/scripts/*.nu']

def main []: nothing -> nothing {
    let files = ($PATTERNS | each {|pattern| glob $pattern } | flatten | sort)
    mut failed = false
    mut exempt = []
    for file in $files {
        let head = (open --raw $file | lines | first 3 | str join "\n")
        if ($head | str contains 'lint-nu: exempt') {
            $exempt = ($exempt | append $file)
            continue
        }
        if (nu-check $file) {
            continue
        }
        print -e $"($file): does not parse"
        $failed = true
    }
    if $failed {
        exit 1
    }
    for file in $exempt {
        print -e $"lint-nu: exempt ($file) \(header marker)"
    }
    print $"lint-nu: ($files | length) nu scripts parse"
}
