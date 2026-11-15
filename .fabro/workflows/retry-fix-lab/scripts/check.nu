#!/usr/bin/env nu
# retry-fix-lab: the DELIBERATE fault (user session 2026-11-14; the
# Part B lab branch restores it — work#1320). This script travels with
# the WORKFLOW VERSION (ADR-0008: graph + prompts + scripts are one
# unit), pinned at run creation — a fix landing on the branch later
# creates a NEW version and never reaches a retried or forked run
# under the plain-retry semantics. That is the gap retry-on-latest
# closes by materializing from the tip.
#
# The fault is PARSE-time (nu 0.116.1 rejects int + string literals
# with operator_incompatible_types while parsing the file — proven by
# the lap-2 agent journal, 2026-11-14), which fires at stage
# execution: nu exits 1 loading the script.
def main [] {
    print "check: opening the lab manifest"
    let fault = (2 + "fault-partb")
    print $"check: the fault state reads ($fault)"
}
