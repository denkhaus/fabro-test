#!/usr/bin/env python3
import json
import sys
from pathlib import Path

path = Path(".fabro/journal/probe.jsonl")
lines = [l for l in path.read_text().splitlines() if l.strip()] if path.is_file() else []
print(json.dumps({"journal_entries": len(lines)}))
print(json.dumps({"preferred_next_label": "Journal ok" if lines else ""}))
sys.exit(0 if lines else 1)
