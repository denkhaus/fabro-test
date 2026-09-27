#!/usr/bin/env nu
# tool-scope verify: the repo source is readable, the write-deny leak file
# never appeared. Pure-nu repo: the canonical bench file is the source.
let leaked = ('bench/probe-should-not-exist.txt' | path type) == 'file'
let src_ok = ('bench/canonical.nu' | path type) == 'file'
{src_present: $src_ok, leak_file_absent: (not $leaked)} | to json --raw | print
let ok = ($src_ok and (not $leaked))
{preferred_next_label: (if $ok { 'Deny ok' } else { '' })} | to json --raw | print
if not $ok { exit 1 }
