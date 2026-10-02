#!/usr/bin/env nu
# land: one-command PR dance for workbench script changes on the PROTECTED
# main (fabro-4b84 follow-up). Takes the DIRTY scripts/ tree as input —
# never resets before committing (the manual dance wiped uncommitted edits
# twice by resetting first: once by seed-ensure's origin reset, once by a
# hand-rolled landing sequence).
#   nu scripts/land.nu 'commit subject'
# Branch bench/workbench -> add scripts/ -> commit -> prune-fetch -> push
# -> PR (reuses an open one) -> wait until checks REPORTED (red `tests` is
# inherited from the stub prestate — admin overrides) -> squash merge
# --admin -> local main resynced -> branch deleted.

def fail [msg: string]: nothing -> nothing {
    print -e $"╔══ LAND ALARM: ($msg) ══╗"
    exit 1
}

def main [subject: string]: nothing -> nothing {
    let branch = 'bench/workbench'
    let sw = (do { git checkout -B $branch --quiet } | complete)
    if $sw.exit_code != 0 { fail $"land: branch: ($sw.stderr | str trim | str substring 0..200)" }
    # .fabro/workflows rides along: probe rigs are bench assets landing
    # through the same dance (fabro-70af probes 17-19, 2026-10-02).
    let add = (do { git add scripts/ justfile .fabro/workflows } | complete)
    if $add.exit_code != 0 { fail $"land: add: ($add.stderr | str trim | str substring 0..200)" }
    let dirty = (do { git status --porcelain } | complete | get stdout | str trim)
    if ($dirty | is-empty) {
        # retry semantics: a prior land may have committed+pushed already and
        # died on a transient GitHub 504 — continue when the branch carries
        # commits beyond origin/main, refuse only when there is truly nothing
        let ahead = (do { git log origin/main..HEAD --oneline } | complete | get stdout | str trim)
        if ($ahead | is-empty) { fail 'land: nothing to commit — pass the edit BEFORE running land' }
    }
    let cm = (do { git -c user.name=denkhaus -c user.email=denkhaus@users.noreply.github.com commit -m $subject --quiet } | complete)
    if $cm.exit_code != 0 { fail $"land: commit: ($cm.stderr | str trim | str substring 0..200)" }
    let pf = (do { git fetch --prune origin --quiet } | complete)
    if $pf.exit_code != 0 { fail $"land: fetch: ($pf.stderr | str trim | str substring 0..200)" }
    let push = (do { git push --force-with-lease origin $"($branch):($branch)" --quiet } | complete)
    if $push.exit_code != 0 { fail $"land: push: ($push.stderr | str trim | str substring 0..200)" }
    let existing = (do { ^gh pr list -R denkhaus/fabro-test --head $branch --state open --json number,url --limit 1 } | complete)
    let open_prs = if $existing.exit_code == 0 { $existing.stdout | from json } else { [] }
    let pr_url = if ($open_prs | is-not-empty) {
        $open_prs | first | get url
    } else {
        let pr = (do { ^gh pr create -R denkhaus/fabro-test --base main --head $branch --title $subject --body 'Workbench script change; red tests is inherited from the stub prestate — bypassed with --admin as the bench always does.' } | complete)
        if $pr.exit_code != 0 { fail $"land: gh pr create: ($pr.stderr | str trim | str substring 0..200)" }
        $pr.stdout | str trim
    }
    mut ready = false
    for _ in 1..60 {
        let roll = (do { ^gh pr view $pr_url -R denkhaus/fabro-test --json statusCheckRollup } | complete)
        if $roll.exit_code == 0 {
            let entries = ($roll.stdout | from json | get -o statusCheckRollup | default [])
            if ($entries | is-not-empty) {
                let pending = ($entries | where {|c| ($c | get -o status | default 'COMPLETED') != 'COMPLETED'})
                if ($pending | is-empty) { $ready = true; break }
            }
        }
        sleep 5sec
    }
    if not $ready { fail $"land: PR checks never finished reporting: ($pr_url)" }
    let merge = (do { ^gh pr merge $pr_url -R denkhaus/fabro-test --squash --admin --delete-branch } | complete)
    if $merge.exit_code != 0 {
        # a 504 can time out the RESPONSE while the merge itself succeeds —
        # verify the PR state before declaring failure
        let st = (do { ^gh pr view $pr_url -R denkhaus/fabro-test --json state } | complete)
        let state = if $st.exit_code == 0 { $st.stdout | from json | get -o state | default '' } else { '' }
        if $state != 'MERGED' { fail $"land: gh pr merge ($pr_url): ($merge.stderr | str trim | str substring 0..200)" }
    }
    let co = (do { git checkout main --quiet } | complete)
    if $co.exit_code != 0 { fail $"land: back to main: ($co.stderr | str trim | str substring 0..200)" }
    let f2 = (do { git fetch --prune origin --quiet } | complete)
    if $f2.exit_code != 0 { fail $"land: refetch: ($f2.stderr | str trim | str substring 0..200)" }
    let reset = (do { git reset --hard origin/main --quiet } | complete)
    if $reset.exit_code != 0 { fail $"land: resync main: ($reset.stderr | str trim | str substring 0..200)" }
    let _ = (do { git branch -D $branch } | complete)
    print $"== land: ($subject) — merged via ($pr_url), main resynced"
}
