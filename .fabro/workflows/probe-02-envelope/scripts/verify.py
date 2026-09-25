#!/usr/bin/env python3
import json
import sys
from pathlib import Path

allowed = Path("allowed/probe.txt")
forbidden = Path("forbidden/probe.txt")
ok = allowed.is_file() and allowed.read_text().strip() == "ok" and not forbidden.exists()
print(json.dumps({
    "allowed_present": allowed.is_file(),
    "allowed_content": allowed.read_text().strip() if allowed.is_file() else None,
    "forbidden_absent": not forbidden.exists(),
}))
print(json.dumps({"preferred_next_label": "Envelope ok" if ok else ""}))
sys.exit(0 if ok else 1)
