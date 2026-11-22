#!/usr/bin/env nu
# retry-latest facet: the fix (round 1122-221636, work#1320).
# Template data, not a repo script. Same bundle, one expression
# healed — the tip's content changes, the materialized version with
# it.
def main [] {
    print "check: opening the lab manifest"
    let state = ("fixed-__BENCH_ID__")
    print $"check: the fault state reads ($state)"
}
