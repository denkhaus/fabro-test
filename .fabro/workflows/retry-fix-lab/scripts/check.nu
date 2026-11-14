#!/usr/bin/env nu
# retry-fix-lab: the DELIBERATE fault (user session 2026-11-14). This
# script travels with the WORKFLOW VERSION (ADR-0008: graph + prompts +
# scripts are one unit), pinned at run creation — a fix landing on main
# later creates a NEW version and never reaches a retried or forked run
# under the current semantics. That is the gap this lab demonstrates.
#
# The fault is a RUNTIME error (not parse-time) so admission accepts the
# workflow and the stage fails in execution.
def main [] {
    print "check: opening the lab manifest"
    # The deliberate fault: type error at runtime (integer + string).
    let fault = (1 + "fault")
    print $"check: unreachable, the fault evaluated to ($fault)"
}
