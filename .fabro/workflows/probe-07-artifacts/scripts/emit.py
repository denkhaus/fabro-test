#!/usr/bin/env python3
from pathlib import Path
Path("out").mkdir(exist_ok=True)
Path("out/report.txt").write_text("probe-07 artifact payload\n")
print("wrote out/report.txt")
