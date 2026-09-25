#!/usr/bin/env python3
"""Drained-tracker fast exit. Fail-open: any error routes non-empty."""
import json
import sys
from pathlib import Path

def emit(label: str) -> None:
    print(json.dumps({"preferred_next_label": label}))
    sys.exit(0)

try:
    lines = Path(".seeds/issues.jsonl").read_text().splitlines()
    open_seeds = [
        json.loads(line)
        for line in lines
        if line.strip() and json.loads(line).get("status") == "open"
    ]
except Exception:
    emit("Tracker non-empty")  # fail-open

emit("Tracker empty" if not open_seeds else "Tracker non-empty")
