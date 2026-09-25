#!/usr/bin/env python3
"""Claim-contract gate: exit 0 iff stdin carries a non-empty seed id."""
import sys

seed_id = sys.stdin.read().strip()
if seed_id:
    print(f"claim ok: {seed_id}")
    sys.exit(0)
print("claim contract failed: current_seed_id is empty")
sys.exit(1)
