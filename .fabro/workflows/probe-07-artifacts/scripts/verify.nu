#!/usr/bin/env nu
# artifact verify: the collected file landed in the workspace again.
let ok = ('out/report.txt' | path type) == 'file'
{report_present: $ok} | to json --raw | print
{preferred_next_label: (if $ok { 'Artifact ok' } else { '' })} | to json --raw | print
if not $ok { exit 1 }
