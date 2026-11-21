# scripts/lib/bench.nu — the bench adapter library (arch review 2026-11-21,
# candidate 1): ONE interface from the bench's drivers and satellites to the
# fabro server and the forge. Every export here was a private copy in one of
# the drivers before (workbench, land, publish-bridge, run-mini, the retry
# satellite) and the copies had already drifted: land.nu:80 parsed the gh
# shape-drift raw (the ab184d0 class — normalized at three sites, forgotten
# at the fourth), and publish-bridge's auth-header lacked the access_token
# fallback. Adapter knowledge lives HERE; drivers are thin callers — one
# fix reaches every caller.
#
# Interface: server · assert-local-server · auth-header · fail ·
#   gh-pr-normalize · gh-pr-list · run-create · run-start · run-wait ·
#   run-lifecycle · events-page · land-pr · const FABRO

# Runplace-agnostic: the server comes from FABRO_SERVER (the bench-wide
# convention, same as run-mini.nu); unset defaults to the local dev stack.
export def server []: nothing -> string {
    $env.FABRO_SERVER? | default 'http://127.0.0.1:32276'
}

# Bench safety (fabro-6041 hygiene rule, 2026-10-24 incident): an exported
# FABRO_SERVER pointing at production silently sent a probe run at
# mirtuell. The bench fires runs and mutates the work registry — refuse
# non-local servers unless FABRO_BENCH_ALLOW_REMOTE=1 is set in the same
# breath as an explicit decision. The workbench calls this at both entries;
# single-purpose drivers resolve without the guard.
export def assert-local-server []: nothing -> nothing {
    let s = (server)
    let local = ($s | str starts-with 'http://127.0.0.1') or ($s | str starts-with 'http://localhost')
    if (not $local) and ($env.FABRO_BENCH_ALLOW_REMOTE? | default '') != '1' {
        print -e $"bench: refusing non-local server '($s)' — the bench fires runs and writes the work registry. Set FABRO_BENCH_ALLOW_REMOTE=1 to force."
        exit 2
    }
}

# The fabro CLI the drivers drive (`just up` in ../fabro refreshes it).
export const FABRO = ('~/.fabro/bin/fabro' | path expand)

export def auth-header []: nothing -> record {
    # dev-token entries carry `token`; OAuth entries carry `access_token`
    # (short-lived — the CLI refreshes it; run the bench with a fresh login
    # window when raw http calls start failing mid-run).
    let s = (open ~/.fabro/auth.json | get servers | get -o (server))
    let token = ($s | get -o token | default ($s | get -o access_token | default ''))
    { Authorization: $"Bearer ($token)" }
}

# The one alarm form (the drift lesson: LAND/BRIDGE/WORKBENCH alarms were
# three copies of the same exit-1 box). The tag carries the driver context.
export def fail [msg: string, tag: string = 'BENCH']: nothing -> nothing {
    print -e $"╔══ ($tag) ALARM: ($msg) ══╗"
    exit 1
}

# gh's pr list shape drifts between builds: some answer a bare record for
# limit 1, others an array — and the old copies normalized it at three
# sites while the fourth parsed raw. Normalize HERE; test fixtures:
# tests/test-bench-lib.nu.
export def gh-pr-normalize [raw: string]: nothing -> list<any> {
    if ($raw | str trim | is-empty) { return [] }
    # null-sentinel, not try/echo: from json's failure modes are not uniform
    # across builds (the fixture test caught garbage answering a string);
    # the any annotation keeps the 0.116 null-init typing lesson happy
    let parsed: any = (try { $raw | from json } catch { null })
    if $parsed == null { return [] }
    let kind = ($parsed | describe)
    # a json array of records parses as a TABLE in nu (describe: table<...>),
    # not a list — pass both through, wrap a bare record, drop everything else
    if (($kind | str starts-with 'list') or ($kind | str starts-with 'table')) { $parsed } else if ($kind | str starts-with 'record') { [$parsed] } else { [] }
}

# gh pr list, normalized: ALWAYS a list (empty when gh errored). Callers
# poll this in loops (index convergence) or read it once (PR reuse).
export def gh-pr-list [
    --repo: string = 'denkhaus/fabro-test'
    --head: string = ''
    --state: string = 'open'
    --fields: list<string> = [number url]
    --limit: int = 1
]: nothing -> list<any> {
    # immutable build: a closure (^gh inside do {}) cannot capture a mut
    let base = ['pr' 'list' '-R' $repo '--state' $state '--json' ($fields | str join ',') '--limit' ($limit | into string)]
    let argv = (if ($head | is-not-empty) { $base | append ['--head' $head] } else { $base })
    let res = (do { ^gh ...$argv } | complete)
    if $res.exit_code != 0 { [] } else { gh-pr-normalize $res.stdout }
}

# The run lifecycle, one verb per piece: probe-run interleaves hooks
# between them (title patch, HITL answering), so the pieces are the real
# interface; run-lifecycle below is the sugar for the tight triplet.
export def run-create [args: list<string>, --what: string = 'run']: nothing -> record {
    let created = (do { ^$FABRO ...$args } | complete)
    let parsed = (if $created.exit_code == 0 { try { $created.stdout | from json } catch { {} } } else { {} })
    {
        exit_code: $created.exit_code,
        stdout: $created.stdout,
        stderr: $created.stderr,
        # the CLI answers run_id; older builds answered id — the fallback
        # is the satellite's specimen lesson, kept in exactly one place
        run_id: ($parsed | get -o run_id | default ($parsed | get -o id | default ''))
    }
}

export def run-start [run_id: string]: nothing -> record {
    do { ^$FABRO start $run_id --server (server) } | complete
}

export def run-wait [run_id: string]: nothing -> record {
    do { ^$FABRO wait $run_id --json --server (server) } | complete
}

# The tight triplet: create -> start -> wait. Fails loudly on create and
# start trouble (the satellite's old silent `let _ =` start would hang the
# facet on a refused start instead); the terminal wait result rides back
# for the caller to judge.
export def run-lifecycle [args: list<string>, --what: string = 'run']: nothing -> record {
    let created = (run-create $args --what $what)
    if $created.exit_code != 0 {
        fail $"($what) create failed: ($created.stderr | str substring 0..200)"
    }
    if ($created.run_id | is-empty) {
        fail $"($what) create answered no id: ($created.stdout | str substring 0..200)"
    }
    let started = (run-start $created.run_id)
    if $started.exit_code != 0 {
        fail $"($what) start failed: ($started.stderr | str substring 0..200)"
    }
    { run_id: $created.run_id, waited: (run-wait $created.run_id) }
}

# The events walk: the stream exceeds one page (the mini's stream carried
# a notification at ~2900 events, bench 0928-205934). Walk up to 12 pages
# of 1000 and return the events PLUS the resume cursor, so a caller can
# poll past a sub-second race (the notification landed milliseconds after
# the walk's window, bench 1031 — the event IS in the stream, the count
# raced it).
export def events-page [run_id: string]: nothing -> record {
    mut evs = []
    mut after = 0
    for _ in 1..12 {
        let page = (http get --headers (auth-header) $"((server))/api/v1/runs/($run_id)/events?limit=1000&after=($after)" | get -o data | default [])
        if ($page | is-empty) { break }
        $after = ($page | last | get stream_seq)
        $evs = ($evs | append $page)
    }
    { events: $evs, after: $after }
}

# The landing (see GLOSSARY.md): bench changes reach the PROTECTED main
# only through this dance. Resumable: a branch carrying commits beyond
# origin/main is KEPT (a prior land may have committed and died on a
# transient GitHub 504); a fresh branch is cut from origin/main, never
# the possibly-stale local main. NEVER resets before committing (the
# manual dance wiped uncommitted edits twice: once by seed-ensure's
# origin reset, once by a hand-rolled landing sequence).
export def land-pr [
    subject: string,
    --branch: string = 'bench/workbench'
    --paths: list<string> = ['scripts/' 'justfile' '.fabro/Dockerfile' '.fabro/workflows' 'tests/' '.github/workflows' 'FACETS.md' 'README.md' 'AGENTS.md' 'GLOSSARY.md']
    --pr-title: string = ''
    --pr-body: string = 'Workbench script change; red tests is inherited from the stub prestate — bypassed with --admin as the bench always does.'
    --tag: string = 'LAND'
] {
    # Sync FIRST (sprint-74 retro, 2026-11-02): a stale local main cut the
    # branch from a pre-merge base — the prior PR's squash-merge showed up
    # as a duplicate commit and GitHub answered CONFLICTING (PR #125).
    let f0 = (do { git fetch --prune origin --quiet } | complete)
    if $f0.exit_code != 0 { fail $"land: fetch: ($f0.stderr | str trim | str substring 0..200)" $tag }
    # A resumable branch (exists, carries commits beyond origin/main) is
    # KEPT; a fresh branch is cut from origin/main. NEVER reset: a dirty
    # tree rides along or the checkout refuses loudly.
    let has_branch = (do { git rev-parse --verify $"refs/heads/($branch)" --quiet } | complete).exit_code == 0
    let ahead_raw = (if $has_branch {
        (do { git log $"origin/main..($branch)" --oneline } | complete)
    } else {
        {exit_code: 1, stdout: '', stderr: ''}
    })
    let resuming = ($has_branch and $ahead_raw.exit_code == 0 and (($ahead_raw.stdout | str trim) != ''))
    if $resuming {
        let count = (($ahead_raw.stdout | lines | length) | into string)
        print $"land: resuming ($branch) with ($count) commit\(s\) beyond origin/main"
        let co = (do { git checkout $branch --quiet } | complete)
        if $co.exit_code != 0 { fail $"land: back to the branch: ($co.stderr | str trim | str substring 0..200)" $tag }
    } else {
        let sw = (do { git checkout -B $branch origin/main --quiet } | complete)
        if $sw.exit_code != 0 {
            fail $"land: branch from origin/main: ($sw.stderr | str trim | str substring 0..200) — local changes conflicting with the newer main must be rebased by hand; land never resets" $tag
        }
    }
    # STAGED, not porcelain: unrelated dirty or untracked files (a sibling
    # agent's work — the roster rule) must neither block the retry nor ride
    # along; land commits exactly what its add list staged.
    let add = (do { git add ...$paths } | complete)
    if $add.exit_code != 0 { fail $"land: add: ($add.stderr | str trim | str substring 0..200)" $tag }
    let staged = (do { git diff --cached --name-only } | complete | get stdout | str trim)
    if ($staged | is-empty) {
        # retry semantics: a prior land may have committed+pushed already
        # and died on a transient GitHub 504 — continue when the branch
        # carries commits beyond origin/main, refuse only when there is
        # truly nothing
        let ahead = (do { git log origin/main..HEAD --oneline } | complete | get stdout | str trim)
        if ($ahead | is-empty) { fail 'land: nothing to commit — pass the edit BEFORE running land' $tag }
        let count = (($ahead | lines | length) | into string)
        print $"land: nothing new to commit — continuing with the ($count) commit\(s\) already on the branch"
    } else {
        let cm = (do { git -c user.name=denkhaus -c user.email=denkhaus@users.noreply.github.com commit -m $subject --quiet } | complete)
        if $cm.exit_code != 0 { fail $"land: commit: ($cm.stderr | str trim | str substring 0..200)" $tag }
    }
    let push = (do { git push --force-with-lease origin $"($branch):($branch)" --quiet } | complete)
    if $push.exit_code != 0 { fail $"land: push: ($push.stderr | str trim | str substring 0..200)" $tag }
    # reuse an OPEN PR when a prior dance stalled mid-way (gh pr view
    # <branch> also returns CLOSED pull requests — merging one always
    # fails with 'Base branch was modified')
    let open_prs = (gh-pr-list --head $branch --state open --fields [number url] --limit 1)
    let pr_url = if ($open_prs | is-not-empty) {
        $open_prs | first | get url
    } else {
        let title = (if ($pr_title | is-empty) { $subject } else { $pr_title })
        let pr = (do { ^gh pr create -R denkhaus/fabro-test --base main --head $branch --title $title --body $pr_body } | complete)
        if $pr.exit_code != 0 { fail $"land: gh pr create: ($pr.stderr | str trim | str substring 0..200)" $tag }
        $pr.stdout | str trim
    }
    # Required checks must REPORT before --admin may merge. The prestate is
    # red BY DESIGN (tests fail against the stub; the mini run makes them
    # green), so wait for every check to be COMPLETED — do not demand
    # green — then merge with the admin override.
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
    if not $ready { fail $"land: PR checks never finished reporting: ($pr_url)" $tag }
    let merge = (do { ^gh pr merge $pr_url -R denkhaus/fabro-test --squash --admin --delete-branch } | complete)
    if $merge.exit_code != 0 {
        # a 504 can time out the RESPONSE while the merge itself succeeds —
        # verify the PR state before declaring failure
        let st = (do { ^gh pr view $pr_url -R denkhaus/fabro-test --json state } | complete)
        let state = if $st.exit_code == 0 { $st.stdout | from json | get -o state | default '' } else { '' }
        if $state != 'MERGED' { fail $"land: gh pr merge ($pr_url): ($merge.stderr | str trim | str substring 0..200)" $tag }
    }
    let co = (do { git checkout main --quiet } | complete)
    if $co.exit_code != 0 { fail $"land: back to main: ($co.stderr | str trim | str substring 0..200)" $tag }
    let f2 = (do { git fetch --prune origin --quiet } | complete)
    if $f2.exit_code != 0 { fail $"land: refetch: ($f2.stderr | str trim | str substring 0..200)" $tag }
    let reset = (do { git reset --hard origin/main --quiet } | complete)
    if $reset.exit_code != 0 { fail $"land: resync main: ($reset.stderr | str trim | str substring 0..200)" $tag }
    let _ = (do { git branch -D $branch } | complete)
    print $"== land: ($subject) — merged via ($pr_url), main resynced"
}
