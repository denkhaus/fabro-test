#!/usr/bin/env nu
# land: one-command landing for bench changes on the PROTECTED main
# (fabro-4b84 follow-up). Takes the DIRTY tree as input — never resets
# before committing (the manual dance wiped uncommitted edits twice: once
# by seed-ensure's origin reset, once by a hand-rolled landing sequence;
# 2026-11-21 the resync became surgical — paths only, bystanders survive).
#   nu scripts/land.nu 'commit subject'
# The dance itself (branch cut/resume from origin/main, push, open-PR
# reuse, wait for checks REPORTED, squash --admin, main resync) lives in
# the bench adapter library: scripts/lib/bench.nu, land-pr.
use lib/bench.nu *

def main [subject: string]: nothing -> nothing {
    land-pr $subject
}
