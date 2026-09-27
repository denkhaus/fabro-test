#!/usr/bin/env nu
# stdin contract check: value must be exactly schema-probe-42.
let value = (^cat | str trim)
print $"probe_key=($value)"
if $value != 'schema-probe-42' { exit 1 }
