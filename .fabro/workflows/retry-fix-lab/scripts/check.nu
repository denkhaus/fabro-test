#!/usr/bin/env nu
# retry-fix-lab: the DELIBERATE fault (user session 2026-11-14). This
# script travels with the WORKFLOW VERSION (ADR-0008: graph + prompts +
# scripts are one unit), pinned at run creation — a fix landing on main
# later creates a NEW version and never reaches a retried or forked run
# under the current semantics. That is the gap this lab demonstrates.
#
# The fault is PARSE-time (nu 0.116.1 rejects int + string literals
# with operator_incompatible_types while parsing the file — proven by
# the lap-2 agent journal, 2026-11-14), which still fires at stage
# execution: nu exits 1 loading the script.
def main [] {
    print "check: opening the lab manifest"
    # FIXED (round 2, 2026-11-14): the reloaded fault is gone — fresh
    # runs at this tip pass; retried/forked runs still pin the faulty
    # version. The decisive contrast for denkhaus/work#1320.
    let fault = ("fault-fixed-on-main-round-2")
    print $"check: the fault state reads ($fault)"
}
