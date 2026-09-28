#!/usr/bin/env nu
# runid verify: every journal line carries a non-empty run id, both from
# the context and from the env var, and the two agree. A ULID run id is
# 26 chars starting with 01.
let lines = (try { open --raw .fabro/journal/probe13.jsonl | lines | where {|l| ($l | str trim) != '' and ($l | str trim) != "''" } } catch { [] })
let parsed = ($lines | each {|l| try { $l | from json } catch { null } } | where {|e| $e != null })
{journal_entries: ($parsed | length)} | to json --raw | print
let bad = ($parsed | where {|e|
    let rid = ($e | get -o ctx_run_id | default '')
    let envr = ($e | get -o env_run_id | default '')
    ($rid | is-empty) or ($rid != $envr) or (($rid | str length) != 26) or (not ($rid | str starts-with '01'))
})
if ($parsed | is-empty) or (not ($bad | is-empty)) {
    {preferred_next_label: ''} | to json --raw | print
    exit 1
}
{preferred_next_label: 'Runid ok'} | to json --raw | print
