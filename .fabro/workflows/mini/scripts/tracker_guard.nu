#!/usr/bin/env nu
# Drained-tracker fast exit. Fail-open: any error routes non-empty.
def emit [label: string] {
    {preferred_next_label: $label} | to json --raw | print
    exit 0
}

let rows = (try {
    open .seeds/issues.jsonl | lines | where {|l| ($l | str trim) != ''} | each {|l| $l | from json}
} catch {
    emit "Tracker non-empty"
})
if (($rows | where status == open | length) == 0) {
    emit "Tracker empty"
}
emit "Tracker non-empty"
