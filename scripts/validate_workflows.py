#!/usr/bin/env python3
"""Validate every .fabro/workflows/*/workflow.fabro via the fabro CLI
(full admission; one graph per invocation so one failure hides none)."""
import pathlib
import subprocess
import sys

fabro = pathlib.Path.home() / ".fabro/bin/fabro"
root = pathlib.Path(__file__).resolve().parents[1]
target = sys.argv[1] if len(sys.argv) > 1 else ""
graphs = sorted((root / ".fabro/workflows").glob(f"*{target}*/workflow.fabro"))
if not graphs:
    print("validate: no workflow graphs found")
    sys.exit(2)
failed = 0
for g in graphs:
    r = subprocess.run([str(fabro), "validate", str(g)], capture_output=True, text=True)
    print(r.stdout, end="")
    if r.returncode != 0:
        print(r.stderr, file=sys.stderr)
        failed += 1
print(f"validate: {len(graphs) - failed}/{len(graphs)} ok")
sys.exit(1 if failed else 0)
