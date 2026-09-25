   #!/usr/bin/env nu
   # Publish bridge (until fabro-ac40 lands the engine publish step):
   # 1. run.diff head_sha via paginated events walk (dev token from auth.json, never printed)
   # 2. docker cp the run snapshot bare repo, push the EXACT final commit as fabro/run/<id>
   # 3. server PR path (`fabro pr create`), gh fallback (PR + squash auto-merge + link)
   #    when the LLM title generation fails (known zai structured-output gap)
   # Usage: nu scripts/publish-bridge.nu <RUN_ID>
const SERVER = 'http://127.0.0.1:32276'
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
    let token = (open ~/.fabro/auth.json | get servers | get -o $SERVER | get -o token | default '')
    { Authorization: $"Bearer ($token)" }
}

def run-diff-head-sha [run_id: string] {
    mut after = null
    for _ in 1..12 {
        let url = if $after == null {
            $"($SERVER)/api/v1/runs/($run_id)/events?limit=1000"
        } else {
            $"($SERVER)/api/v1/runs/($run_id)/events?limit=1000&after=($after)"
        }
        let page = (http get --headers (auth-header) $url | get -o data | default [])
        if ($page | is-empty) { break }
        $after = ($page | last | get stream_seq)
        let hit = ($page | where item.record.kind == run.diff | select -o 0 | get -o item.record.head_sha)
        if ($hit | is-not-empty) { return ($hit | first) }
    }
    fail 'no run.diff record in run events'
}

def main [run_id: string] {
    let sha = (run-diff-head-sha $run_id)
    print $"== bridge: run ($run_id) final commit ($sha)"

    let day = (date now | format date '%Y%m%d')
    let snap = $"/storage/scratch/($day)-($run_id)/petri/snapshots/invocation-0-scope-0.git"
    let tmpdir = (mktemp --directory)
    let tmpgit = ($tmpdir | path join 'snap.git')
    ok (do { docker cp $"fabro-fabro-1:($snap)" $tmpgit } | complete) 'docker cp snapshot'

    print $"== bridge: pushing exact final commit as fabro/run/($run_id)"
    ok (do { git --git-dir $tmpgit push $ORIGIN $"($sha):refs/heads/fabro/run/($run_id)" } | complete) 'snapshot push'
    rm -rf $tmpdir

    print '== bridge: creating PR (server path first)'
    let created = (do { ^$FABRO pr create $run_id --model ($env.PR_MODEL? | default 'glm-4.7') --server $SERVER } | complete)
    if $created.exit_code == 0 {
        print '== bridge: done (engine-created PR)'
        return
    }
    print $"   server PR path failed — gh fallback: (($created.stderr | str trim) | str substring 0..120)"

    let title = $"Mini run ($run_id) (bridge publish)"
    let body = $"Run ($run_id) work from the run snapshot at final commit ($sha). Bridge-created; engine PR generation unavailable."
    let pr = (ok (do { ^gh pr create -R $REPO --base main --head $"fabro/run/($run_id)" --title $title --body $body } | complete) 'gh pr create')
    let pr_url = ($pr.stdout | str trim)
    ok (do { ^gh pr merge -R $REPO --squash --auto $pr_url } | complete) 'gh pr merge'
    ok (do { ^$FABRO pr link $run_id $pr_url --server $SERVER } | complete) 'fabro pr link'
    print $"== bridge: done (gh fallback) — ($pr_url)"
}
