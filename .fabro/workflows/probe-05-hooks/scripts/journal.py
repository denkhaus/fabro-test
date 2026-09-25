#!/usr/bin/env python3
"""stage_complete hook: append one JSON line to the run workspace journal."""
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

entry = {
    "ts": datetime.now(timezone.utc).isoformat(),
    "event": "stage_complete",
    "context": (os.environ.get("FABRO_HOOK_CONTEXT") or "")[:200],
}
path = Path(".fabro/journal/probe.jsonl")
path.parent.mkdir(parents=True, exist_ok=True)
with path.open("a") as fh:
    fh.write(json.dumps(entry) + "\n")
sys.exit(0)
