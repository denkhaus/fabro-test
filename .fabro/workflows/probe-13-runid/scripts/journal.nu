#!/usr/bin/env nu
# stage_complete hook: append the run id from BOTH sources — the hook
# context JSON (ctx.run_id) and the FABRO_RUN_ID env var — to the run
# workspace journal. Pre-fabro-6558 both were empty, so the stage journal
# landed in .fabro/journal/.jsonl instead of <run_id>.jsonl.
let ctx_path = ($env.FABRO_HOOK_CONTEXT? | default '')
let ctx = (if ($ctx_path | is-empty) { {} } else { open $ctx_path })
let entry = {
    ts: (date now | format date '%Y-%m-%dT%H:%M:%S.%fZ')
    ctx_run_id: ($ctx | get -o run_id | default '')
    env_run_id: ($env.FABRO_RUN_ID? | default '')
}
mkdir .fabro/journal
if ((('.fabro/journal/probe13.jsonl') | path type) == null) {
    [''] | save --force .fabro/journal/probe13.jsonl
}
open --raw .fabro/journal/probe13.jsonl | append ($entry | to json --raw) | str join "\n" | $"($in)\n" | save --force .fabro/journal/probe13.jsonl
