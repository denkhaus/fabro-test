#!/usr/bin/env python3
import json
import sys
from pathlib import Path

leaked = Path("src/probe-should-not-exist.txt").exists()
src_ok = Path("src/utils.py").is_file()
ok = src_ok and not leaked
print(json.dumps({"src_present": src_ok, "leak_file_absent": not leaked}))
print(json.dumps({"preferred_next_label": "Deny ok" if ok else ""}))
sys.exit(0 if ok else 1)
