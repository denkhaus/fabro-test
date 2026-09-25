#!/usr/bin/env python3
import sys
child = sys.stdin.read().strip()
print(f"child_run_id={child}")
sys.exit(0 if child.startswith("01M") else 1)
