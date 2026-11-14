# retry-latest facet (work#1320): the self-contained drive — a faulty
# workflow version fails a run, the fixed version re-admits through
# POST /runs/{id}/retry-latest, and the successor goes green with the
# checkpoint work carried. Both versions are registered through the
# workflow-versions API (nothing mutates the repo tree); the specimen
# graph is two command stages — work (a real file append, the
# checkpoint payload) and check (the fault carrier: a parse-time type
# error in v1, fixed in v2).

# The faulty and fixed check scripts (the experiment variable).
const CHECK_FAULTY = "exit 1"
const CHECK_FIXED = "echo check-green"

# The specimen graph: work makes a real change (the carried commit),
# check is the fault carrier. Parallelogram = command stages.
def facet-graph [check: string]: nothing -> string {
    # The DOT rides a plain file (scripts/facet-graph-template.dot)
    # with a __CHECK__ placeholder — no nu string parsing touches it
    # (the lesson of six escaping rounds); CWD is the repo root the
    # workbench runs from.
    open --raw scripts/facet-graph-template.dot | str replace "__CHECK__" $check
}

# Register one specimen version; the id rides the API's answer.
def facet-register-version [graph: string]: nothing -> string {
    # The version bundle is SELF-CONTAINED: the environment Dockerfile
    # rides INSIDE it (bundle-relative path — a ../../ escape is what
    # the raw API rightly refuses; the CLI publish path resolves and
    # embeds it the same way).
    let dockerfile = (open --raw .fabro/Dockerfile)
    let files = {
        "workflow.fabro": $graph,
        "workflow.toml": ("_version = 1\n\n[workflow]\ngraph = \"workflow.fabro\"\n\n[run.model]\nprovider = \"zai\"\nname = \"glm-4.7\"\n\n[environments.toolchain]\nprovider = \"docker\"\n\n[environments.toolchain.image]\ndockerfile = { path = \"Dockerfile\" }\n"),
        "Dockerfile": $dockerfile,
    }
    let body = {
        entrypoint: "workflow.fabro",
        files: $files,
        workflow_dependencies: {}
    }
    let res = (http post --headers (auth-header) -t 'application/json' $"((server))/api/v1/workflow-versions" ($body | to json -r))
    # The answer names the registered id (versionId / id — take either).
    let id = ($res | get -o versionId | default ($res | get -o id | default ($res | get -o data.versionId) | default ($res | get -o data.id)))
    if ($id | is-empty) {
        error make {msg: $"retry-latest facet: version registration answered no id: ($res | to json -r | str substring 0..200)"}
    }
    $id
}

# Create a run from an explicit version (the intent path — no local
# tree resolution), start it, and wait terminal.
def facet-run-from-version [version_id: string, label: string]: nothing -> string {
    let intent = {
        workflow_version_id: $version_id,
        target: {kind: "none"},
        environment_id: "toolchain",
        args: {labels: {bench: $label}}
    }
    let created = (http post --headers (auth-header) -t 'application/json' $"((server))/api/v1/runs" ($intent | to json -r))
    let run_id = ($created | get -o id | default ($created | get -o data.id))
    if ($run_id | is-empty) {
        error make {msg: $"retry-latest facet: run creation answered no id: ($created | to json -r | str substring 0..200)"}
    }
    let _ = (do { ^$FABRO start $run_id --server (server) } | complete)
    let _ = (^$FABRO wait $run_id --json --server (server) | complete)
    $run_id
}

# The facet drive: faulty version -> failed run -> fixed version ->
# retry-latest -> green successor with carried work. Returns the facet
# record for the table.
export def retry-latest-facet [bench_id: string]: nothing -> record {
    # v1: the faulty specimen fails.
    let faulty_id = (facet-register-version (facet-graph $CHECK_FAULTY))
    let failed_run = (facet-run-from-version $faulty_id $bench_id)
    let failed_status = (^$FABRO ps -a --json --server (server) | from json | where run_id == $failed_run | get 0.status.kind)
    if $failed_status != 'failed' {
        return {facet: 'probe-45-retry-latest', ok: false, detail: $"specimen expected failed, got ($failed_status)"}
    }

    # v2: the fixed version, re-driven through the door.
    let fixed_id = (facet-register-version (facet-graph $CHECK_FIXED))
    let res = (http post --headers (auth-header) -t 'application/json' $"((server))/api/v1/runs/($failed_run)/retry-latest" '{}')
    let new_run = ($res | get -o new_run_id | default ($res | get -o data.new_run_id))
    if ($new_run | is-empty) {
        return {facet: 'probe-45-retry-latest', ok: false, detail: $"retry-latest answered no successor: ($res | to json -r | str substring 0..200)"}
    }
    let carried = ($res | get -o carried_commits | default ($res | get -o data.carried_commits) | default 0)
    let _ = (^$FABRO wait $new_run --json --server (server) | complete)
    let status = (^$FABRO ps -a --json --server (server) | from json | where run_id == $new_run | get 0.status.kind)

    # Board hygiene: both specimens leave immediately.
    let body = ({ run_ids: [$failed_run, $new_run], force: true } | to json -r)
    let _ = (http post --headers (auth-header) -t 'application/json' $"((server))/api/v1/runs/delete" $body)

    let ok = ($status == 'succeeded' and $carried >= 1)
    {facet: 'probe-45-retry-latest', ok: $ok, detail: $"successor ($status), carried ($carried) commit(s)"}
}
