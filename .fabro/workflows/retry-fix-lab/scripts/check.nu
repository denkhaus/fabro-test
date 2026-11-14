#!/usr/bin/env nu
# retry-fix-lab: the DELIBERATE fault (user session 2026-11-14). This
# script travels with the WORKFLOW VERSION (ADR-0008: graph + prompts +
# scripts are one unit), pinned at run creation — a fix landing on main
# later creates a NEW version and never reaches a retried or forked run
# under the current semantics. That is the gap this lab demonstrates.
#
# The fault: `1 + "fault"` is a TYPE error that nu 0.116.1 rejects at
# PARSE time (nu::parser::operator_incompatible_types) — the original
# "runtime error" claim was wrong (observed in lab run
# 01M7CQG5NM79NS8EWVRYQKBKDP). Admission accepts the workflow either
# way; at execution the stage exits non-zero and, with the check
# node's on_failure="exit", the run blocks AT check.
def main [] {
    print "check: opening the lab manifest"
    # The deliberate fault: type error (integer + string). NEVER fix
    # this line to unblock a pinned run — a fix belongs on main as the
    # lab's separate fix leg, and only fresh runs pick it up.
    let fault = (1 + "fault")
    print $"check: unreachable, the fault evaluated to ($fault)"
}
