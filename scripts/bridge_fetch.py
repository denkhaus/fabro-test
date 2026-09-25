#!/usr/bin/env python3
"""Bridge helper: fetch base_sha + unified patch for a finished run.

Reads the local dev token from ~/.fabro/auth.json (never prints it).
Output (stdout): two lines -- base_sha, then the concatenated patch.
"""
import json
import sys
import urllib.request
from pathlib import Path

SERVER = "http://127.0.0.1:32276"
run_id = sys.argv[1]

token = json.loads((Path.home() / ".fabro/auth.json").read_text())["servers"][SERVER]["token"]

def get(path: str):
    req = urllib.request.Request(f"{SERVER}{path}",
                                 headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)

base = None
data = get(f"/api/v1/runs/{run_id}/events?limit=1000").get("data", [])
for ev in data:
    rec = ev.get("item", {}).get("record", {})
    if rec.get("kind") == "run.branch":
        base = rec.get("base_sha")
        break
if not base:
    sys.exit("bridge_fetch: no run.branch base_sha in events")

files = get(f"/api/v1/runs/{run_id}/files").get("data", [])
patch = "\n".join(f.get("unified_patch") or "" for f in files).strip()
if not patch:
    sys.exit("bridge_fetch: empty patch (nothing to publish?)")

print(base)
print(patch)
