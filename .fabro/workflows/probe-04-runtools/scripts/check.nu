#!/usr/bin/env nu
# stdin contract check: the spawned child run id must look like 01M…
let child = (^cat | str trim)
print $"child_run_id=($child)"
if not ($child | str starts-with '01M') { exit 1 }
