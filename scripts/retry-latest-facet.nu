# retry-latest facet (work#1320, Part B shape): the git-backed drive —
# a faulty workflow tip fails a run, the fix lands ON THE SAME BRANCH
# (the tip moves, the bundle content changes), and retry-on-latest
# MATERIALIZES the fixed version from that tip: no other run of the
# slug needs to register it first (the run-scan resolution's 409
# window, killed by Part B). The successor must check out the TIP sha
# and carry the source's checkpoint work from its snapshot repository.
#
# The first draft drove a none-target specimen with explicit versions;
# that drive can never pass the door — retry-on-latest needs a
# git-backed source, and materialization reads the target branch tip.
# The specimen workflow is fabro-test's retry-fix-lab (two stages:
# work writes the checkpoint payload, check carries the fault); the
# faulty/fixed check scripts land on a probe branch through the GitHub
# contents API (no local checkout dance, no worktree churn — the
# workbench runs from this repository and must not switch branches).
# Each round embeds the bench id in the script content: the version is
# content-addressed, so every round mints fresh versions and the
# equal-version guard never interferes with a previous round.

# The faulty and fixed check scripts (the experiment variable), loaded
# from template FILES with a __BENCH_ID__ placeholder — no nu string
# parsing touches the script content (the lesson of the first draft's
# six escaping rounds: an interpolated string parses the script's own
# parentheses as interpolations). The fault is PARSE-time (nu rejects
# int + string literals while parsing the file): nu exits 1 loading
# the script, before any command runs.
def check-script [faulty: bool, bench_id: string]: nothing -> string {
    let template = (if $faulty { 'facet-check-faulty.nu.txt' } else { 'facet-check-fixed.nu.txt' })
    open --raw $"scripts/($template)" | str replace "__BENCH_ID__" $bench_id
}

const PROBE_BRANCH = 'bench/retry-latest-probe'
const REPO = 'denkhaus/fabro-test'
const CHECK_PATH = '.fabro/workflows/retry-fix-lab/scripts/check.nu'

# Put the check script's content on the probe branch through the
# GitHub contents API (one commit; the branch is created from main on
# the first round). Returns the branch's new tip sha.
def push-check [content: string, bench_id: string]: nothing -> string {
    let exists = (do { gh api $"repos/($REPO)/branches/($PROBE_BRANCH)" --silent } | complete)
    if $exists.exit_code != 0 {
        let main_sha = (gh api $"repos/($REPO)/branches/main" --jq .commit.sha)
        gh api -X POST $"repos/($REPO)/git/refs" -f $"ref=refs/heads/($PROBE_BRANCH)" -f $"sha=($main_sha)" --silent
    }
    let file = (gh api $"repos/($REPO)/contents/($CHECK_PATH)?ref=($PROBE_BRANCH)" --jq .sha)
    gh api -X PUT $"repos/($REPO)/contents/($CHECK_PATH)" -f $"message=retry-latest facet: check script round ($bench_id)" -f $"content=($content | encode base64)" -f $"branch=($PROBE_BRANCH)" -f $"sha=($file)" --silent
    gh api $"repos/($REPO)/branches/($PROBE_BRANCH)" --jq .commit.sha
}

# Create the specimen run at the probe branch's tip (the CLI collects
# and registers the workflow AT THE REF — the source run pins the
# faulty version), start it, and wait terminal.
def specimen-run [bench_id: string]: nothing -> string {
    let create_args = [
        'create' 'retry-fix-lab'
        '--workflow-repo' 'denkhaus/fabro-test'
        '--workflow-ref' $PROBE_BRANCH
        '--target' $"denkhaus/fabro-test@($PROBE_BRANCH)"
        '--environment' 'toolchain'
        '--label' $"bench=($bench_id)"
        '--json' '--server' (server)
    ]
    let created = (do { ^$FABRO ...$create_args } | complete)
    if $created.exit_code != 0 {
        error make {msg: $"retry-latest facet: specimen create failed: ($created.stderr | str substring 0..300)"}
    }
    let run_id = ($created.stdout | from json | get -o run_id | default ($created.stdout | from json | get -o id))
    if ($run_id | is-empty) {
        error make {msg: $"retry-latest facet: specimen create answered no id: ($created.stdout | str substring 0..300)"}
    }
    let _ = (do { ^$FABRO start $run_id --server (server) } | complete)
    let _ = (^$FABRO wait $run_id --json --server (server) | complete)
    $run_id
}

def run-kind [run_id: string]: nothing -> string {
    ^$FABRO ps -a --json --server (server)
        | from json
        | where run_id == $run_id
        | get 0.status.kind
}

# The successor's checkout sha: the run detail's target names the
# pinned commit the worktree was prepared at (a git target object with
# repo/branch/sha).
def checkout-sha [run_id: string]: nothing -> string {
    let detail = (http get --headers (auth-header) $"((server))/api/v1/runs/($run_id)")
    let target = ($detail | get -o target | default ($detail | get -o data.target | default null))
    if $target == null {
        ''
    } else {
        $target | get -o sha | default ''
    }
}

# The facet drive: faulty tip -> failed specimen -> fix moves the tip
# -> retry-latest materializes from the tip -> green successor with
# carried work, checked out at the tip. Returns the facet record.
export def retry-latest-facet [bench_id: string]: nothing -> record {
    # v1: the faulty tip fails the specimen after the work stage wrote
    # its checkpoint payload.
    let faulty_tip = (push-check (check-script true $bench_id) $bench_id)
    let failed_run = (specimen-run $bench_id)
    let failed_status = (run-kind $failed_run)
    if $failed_status != 'failed' {
        let body = ({ run_ids: [$failed_run], force: true } | to json -r)
        let _ = (http post --headers (auth-header) -t 'application/json' $"((server))/api/v1/runs/delete" $body)
        return {facet: 'probe-45-retry-latest', ok: false, detail: $"specimen expected failed, got ($failed_status)"}
    }

    # v2: the fix lands on the SAME branch — the tip moves, the
    # materialized content changes, and no other run of the slug
    # registered it (Part B: materialization, never a run scan).
    let fixed_tip = (push-check (check-script false $bench_id) $bench_id)
    let res = (http post --headers (auth-header) -t 'application/json' $"((server))/api/v1/runs/($failed_run)/retry-latest" '{}')
    let new_run = ($res | get -o new_run_id | default ($res | get -o data.new_run_id))
    if ($new_run | is-empty) {
        let body = ({ run_ids: [$failed_run], force: true } | to json -r)
        let _ = (http post --headers (auth-header) -t 'application/json' $"((server))/api/v1/runs/delete" $body)
        return {facet: 'probe-45-retry-latest', ok: false, detail: $"retry-latest answered no successor: ($res | to json -r | str substring 0..300)"}
    }
    let carried = ($res | get -o carried_commits | default ($res | get -o data.carried_commits) | default 0)
    let _ = (^$FABRO wait $new_run --json --server (server) | complete)
    let status = (run-kind $new_run)
    let checkout = (checkout-sha $new_run)

    # Board hygiene: both specimens leave immediately.
    let body = ({ run_ids: [$failed_run, $new_run], force: true } | to json -r)
    let _ = (http post --headers (auth-header) -t 'application/json' $"((server))/api/v1/runs/delete" $body)

    let carried_ok = ($carried >= 1)
    let tip_ok = ($checkout == $fixed_tip)
    let ok = ($status == 'succeeded' and $carried_ok and $tip_ok)
    {facet: 'probe-45-retry-latest', ok: $ok, detail: $"successor ($status), carried ($carried) commits, checkout ($checkout) vs tip ($fixed_tip)"}
}
