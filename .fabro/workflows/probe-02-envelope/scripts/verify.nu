#!/usr/bin/env nu
# fs-envelope verify: allowed/ readable, forbidden/ absent.
let allowed_ok = ('allowed/probe.txt' | path type) == 'file'
let content = (if $allowed_ok { open --raw allowed/probe.txt | str trim } else { null })
let forbidden_absent = not (('forbidden/probe.txt' | path type) == 'file')
{allowed_present: $allowed_ok, allowed_content: $content, forbidden_absent: $forbidden_absent} | to json --raw | print
let ok = ($allowed_ok and ($content == 'ok') and $forbidden_absent)
{preferred_next_label: (if $ok { 'Envelope ok' } else { '' })} | to json --raw | print
if not $ok { exit 1 }
