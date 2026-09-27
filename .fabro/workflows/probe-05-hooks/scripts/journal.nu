#!/usr/bin/env nu
# stage_complete hook: append one JSON line to the run workspace journal.
let entry = {
    ts: (date now | format date '%Y-%m-%dT%H:%M:%S.%fZ')
    event: 'stage_complete'
    context: ($env.FABRO_HOOK_CONTEXT? | default '' | str substring 0..200)
}
mkdir .fabro/journal
let line = ($entry | to json --raw)
if (('probe.jsonl' | path type) == null) {
    # first entry: create, do not open (open on a missing file errors)
    [''] | save --force .fabro/journal/probe.jsonl
}
open --raw .fabro/journal/probe.jsonl | append $line | str join "\n" | $"($in)\n" | save --force .fabro/journal/probe.jsonl
