#!/usr/bin/env python3
"""Close exactly this run's seed (id on stdin) in .seeds/issues.jsonl."""
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

seed_id = sys.stdin.read().strip()
if not seed_id:
    print("closeout failed: empty seed id on stdin", file=sys.stderr)
    sys.exit(1)

path = Path(".seeds/issues.jsonl")
rows = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]

hits = [r for r in rows if r.get("id") == seed_id]
if not hits:
    print(f"closeout failed: {seed_id} not found", file=sys.stderr)
    sys.exit(1)

now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")
for row in rows:
    if row.get("id") == seed_id:
        row["status"] = "closed"
        row["updatedAt"] = now

path.write_text("\n".join(json.dumps(r) for r in rows) + "\n")
print(f"closed {seed_id}")
