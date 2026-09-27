#!/usr/bin/env nu
# Canonical bench acceptance: bench/canonical.nu prints the required
# marker. Run by the mini gate from the workspace root:
#   nu tests/test-canonical.nu
let res = (do { ^nu bench/canonical.nu } | complete)
if $res.exit_code != 0 {
    print -e $"test-canonical: canonical_mark still fails: ($res.stderr | str trim)"
    exit 1
}
let marker = ($res.stdout | str trim)
if $marker != 'canonical-ok-9001' {
    print -e $"test-canonical: expected canonical-ok-9001, got ($marker)"
    exit 1
}
print 'test-canonical: canonical-ok-9001 ok'
