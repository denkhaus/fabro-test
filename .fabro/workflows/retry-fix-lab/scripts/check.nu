#!/usr/bin/env nu
# retry-latest facet: the DELIBERATE fault (round 1123-000147,
# work#1320). Template data, not a repo script: the facet loads it and
# substitutes the round id (the version is content-addressed, so every
# round mints fresh versions). The fault is PARSE-time — nu rejects
# int + string literals while parsing the file, so nu exits 1 loading
# the script, before any command runs.
def main [] {
    print "check: opening the lab manifest"
    let fault = (2 + "fault-__BENCH_ID__")
    print $"check: the fault state reads ($fault)"
}
