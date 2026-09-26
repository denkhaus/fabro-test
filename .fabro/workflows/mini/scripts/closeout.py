#!/usr/bin/env python3
"""Close exactly this run's seed (id on stdin) through the seeds CLI.

Tracker mutations go EXCLUSIVELY through the seeds app — never a direct
file write (operator directive 2026-09-26: a run's hand-written JSONL
caused format drift and a full-file merge conflict, PR #6 vs PR #7).
Fails closed when the sandbox has no seeds binary: a red closeout beats
a silent rule violation. Enablement of seeds in the run sandbox is
tracked by seeds-e160 (mise cargo backend fails in the toolchain image).
"""
import shutil
import subprocess
import sys

seed_id = sys.stdin.read().strip()
if not seed_id:
    print("closeout failed: empty seed id on stdin", file=sys.stderr)
    sys.exit(1)

if shutil.which("seeds") is None:
    print(
        "closeout failed: the seeds CLI is not available in this sandbox "
        "(seeds-e160); refusing to write .seeds/issues.jsonl by hand",
        file=sys.stderr,
    )
    sys.exit(1)

completed = subprocess.run(
    ["seeds", "close", seed_id], capture_output=True, text=True
)
if completed.stdout:
    sys.stdout.write(completed.stdout)
if completed.returncode != 0:
    print(
        f"closeout failed: seeds close {seed_id}: "
        f"{completed.stderr.strip()}",
        file=sys.stderr,
    )
    sys.exit(1)
print(f"closed {seed_id}")
