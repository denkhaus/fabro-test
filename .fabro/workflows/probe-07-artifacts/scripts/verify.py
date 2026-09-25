#!/usr/bin/env python3
import json
import sys
from pathlib import Path

ok = Path("out/report.txt").is_file()
print(json.dumps({"report_present": ok}))
print(json.dumps({"preferred_next_label": "Artifact ok" if ok else ""}))
sys.exit(0 if ok else 1)
