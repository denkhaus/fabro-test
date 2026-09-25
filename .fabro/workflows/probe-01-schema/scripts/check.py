#!/usr/bin/env python3
import sys
value = sys.stdin.read().strip()
print(f"probe_key={value}")
sys.exit(0 if value == "schema-probe-42" else 1)
