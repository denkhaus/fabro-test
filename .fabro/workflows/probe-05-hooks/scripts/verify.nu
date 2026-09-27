#!/usr/bin/env nu
# journal verify: the hook appended at least one entry.
let lines = (try { open --raw .fabro/journal/probe.jsonl | lines | where {|l| ($l | str trim) != ''} } catch { [] })
{journal_entries: ($lines | length)} | to json --raw | print
if ($lines | is-empty) {
    {preferred_next_label: ''} | to json --raw | print
    exit 1
}
{preferred_next_label: 'Journal ok'} | to json --raw | print
