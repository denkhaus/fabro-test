   #!/usr/bin/env nu
   # Publish bridge (until fabro-ac40 lands the engine publish step):
   # 1. run.diff head_sha via paginated events walk (dev token from auth.json, never printed)
   # 2. docker cp the run snapshot bare repo, push the EXACT final commit as fabro/run/<id>
   # 3. server PR path (`fabro pr create`), gh fallback (PR + squash auto-merge + link)
   #    when the LLM title generation fails (known zai structured-output gap)
   # Usage: nu scripts/publish-bridge.nu <RUN_ID>
# Runplace-agnostic: FABRO_SERVER like run-mini.nu; default = local stack.
def server []: nothing -> string { $env.FABRO_SERVER? | default 'http://127.0.0.1:32276' }
const REPO = 'denkhaus/fabro-test'
const ORIGIN = 'https://github.com/denkhaus/fabro-test.git'
const FABRO = ('~/.fabro/bin/fabro' | path expand)

def fail [msg: string]: nothing -> nothing {
    print -e $"╔══ BRIDGE ALARM: ($msg) ══╗"
    exit 1
}

def ok [result: record, what: string]: nothing -> record {
    if $result.exit_code != 0 {
        let detail = ($result.stderr | str trim | default ($result.stdout | str trim))
        fail $"($what) failed: ($detail)"
    }
    $result
}

def auth-header []: nothing -> record {
    let token = (open ~/.fabro/auth.json | get servers | get -o (server) | get -o token | default '')
    { Authorization: $"Bearer ($token)" }
}

def run-diff-head-sha [run_id: string] {
        mut after = 0
        for _ in 1..12 {
            let url = $"((server))/api/v1/runs/($run_id)/events?limit=1000&after=($after)"
            let page = (http get --headers (auth-header) $url | get -o data | default [])
            if ($page | is-empty) { break }
            $after = ($page | last | get stream_seq)
            let hit = ($page | where {|e| (($e | get -o item.record.kind | default '') == 'run.diff')} | first | default null)
            let sha = if $hit == null { '' } else { ($hit | get -o item.record.head_sha | default '') }
            if ($sha | is-not-empty) { return $sha }
        }
        fail 'no run.diff record in run events'
    }

def main [run_id: string] {
    let sha = (run-diff-head-sha $run_id)
    print $"== bridge: run ($run_id) final commit ($sha)"

    # Do NOT guess the date (UTC/local midnight drift): resolve the scratch
    # dir by run id inside the container.
    let dir = (do { docker exec fabro-lokal sh -c $"ls -d /storage/scratch/*-($run_id) 2>/dev/null | head -1" } | complete | get stdout | str trim)
    if ($dir | is-empty) { fail $"no scratch dir for ($run_id)" }
    let snap = $"($dir)/petri/snapshots/invocation-0-scope-0.git"
    let tmpdir = (mktemp --directory)
    let tmpgit = ($tmpdir | path join 'snap.git')
    ok (do { docker cp $"fabro-lokal:($snap)" $tmpgit } | complete) 'docker cp snapshot'

    print $"== bridge: pushing exact final commit as fabro/run/($run_id)"
    ok (do { git --git-dir $tmpgit push $ORIGIN $"($sha):refs/heads/fabro/run/($run_id)" } | complete) 'snapshot push'
    rm -rf $tmpdir

    print '== bridge: creating PR (server path first)'
    let created = (do { ^$FABRO pr create $run_id --model ($env.PR_MODEL? | default 'glm-4.7') --server (server) } | complete)
    if $created.exit_code == 0 {
        let url = ($created.stdout | str trim | lines | last | default '')
        print $"== bridge: engine PR ($url)"
        # fabro-4c11 remainder: the engine PR body must be LLM-generated.
        # The deterministic skeleton notice (EMPTY_BODY_NOTICE in
        # fabro-workflow/src/pull_request.rs) or an empty body means the
        # configured PR model still never reaches the client in route form.
        let body = (do { ^gh pr view $url -R $REPO --json body -q .body } | complete)
        if $body.exit_code != 0 { fail $"engine PR body fetch failed: ($body.stderr | str trim | str substring 0..200)" }
        let b = ($body.stdout | str trim)
        if ($b | is-empty) { fail 'engine PR body is empty — PR-content generation produced nothing (fabro-4c11 class)' }
        if ($b | str contains 'The LLM did not produce a description') {
            fail 'engine PR body is the deterministic skeleton — the PR-content model path is still broken (fabro-4c11)'
        }
        print $"== bridge: done (engine-created PR, body ($b | str length) chars — generated, not the skeleton)"
        return
    }
    # The bench is the engine gate: a gh-fallback PR would mask exactly the
    # regression class fabro-4c11 pins, so the fallback now fails the bridge.
    # (Manual repair recipe, kept here on purpose: the snapshot push above
    # already happened — gh pr create --head fabro/run/<id>, squash --auto,
    # fabro pr link <run> <url>.)
    print $"   server PR path failed: (($created.stderr | str trim) | str substring 0..160)"
    fail "engine PR path unavailable — the bench gate requires it (fabro-4c11 verification); the gh recipe above is for incident repair only"
}
