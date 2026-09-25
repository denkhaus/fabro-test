#!/usr/bin/env python3
"""Evidence capture: run-scoped diff + commits + worktree state.

Diff base = parent of THIS run's oldest checkpoint commit (subject
'fabro(<run-id>):'), like develop's evidence.nu — no origin refs needed.
Fallback base = HEAD (grounded:false) instead of failing: a capture must
never strand the run (soft-exit path costs a full re-cycle).
"""
import re
import subprocess
import sys

def sh(*args: str) -> str:
    # The engine prepares /workspace as a different UID than the run
    # user; every git call needs the ownership exemption or git exits
    # 128 with "detected dubious ownership".
    if args and args[0] == "git":
        args = ("git", "-c", "safe.directory=*", *args[1:])
    p = subprocess.run(args, capture_output=True, text=True)
    if p.returncode != 0:
        print(f"evidence: {' '.join(args[:2])} failed: {p.stderr.strip()}", file=sys.stderr)
        sys.exit(1)
    return p.stdout

branch = sh("git", "rev-parse", "--abbrev-ref", "HEAD").strip()
m = re.fullmatch(r"fabro/run/([^/]+)", branch)
run_id = m.group(1) if m else ""

base = "HEAD"
grounded = False
if run_id:
    mark = f"fabro({run_id}):"
    log = sh("git", "log", "--format=%H", "--fixed-strings", "--grep", mark)
    checkpoints = [l for l in log.splitlines() if l.strip()]
    if checkpoints:
        base = sh("git", "rev-parse", f"{checkpoints[-1]}^").strip()
        grounded = True

short = sh("git", "rev-parse", "--short", base).strip()
print(f"== evidence (base {short}{'' if grounded else ' UNGROUNDED-fallback'}) ==")
print("-- diff (committed seed work) --")
print(sh("git", "--no-pager", "diff", base))
print("-- commits --")
print(sh("git", "--no-pager", "log", "--oneline", f"{base}..HEAD"))
print("-- worktree status --")
print(sh("git", "--no-pager", "status", "--porcelain"))
