#!/usr/bin/env nu
# stdin contract check: the skill-applied marker must appear in the text.
let text = (^cat)
let ok = ($text | str contains 'BENCH-SKILL-APPLIED')
print $"marker_present=($ok)"
if not $ok { exit 1 }
