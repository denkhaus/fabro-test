#!/usr/bin/env python3
import sys
text = sys.stdin.read()
ok = "BENCH-SKILL-APPLIED" in text
print(f"marker_present={ok}")
sys.exit(0 if ok else 1)
