#!/usr/bin/env bash
# Thin local runner: create -> start -> attach -> wait. Red run -> exit 1.
# Usage: scripts/run-mini.sh ["goal text"]
set -euo pipefail
cd "$(dirname "$0")/.."

SERVER="${FABRO_SERVER:-http://127.0.0.1:32276}"

if [ $# -gt 0 ]; then
    json=$(fabro create mini --goal "$1" --environment test-local --json --server "$SERVER")
else
    json=$(fabro create mini --environment test-local --json --server "$SERVER")
fi
run_id=$(printf '%s' "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["run_id"])')
echo "== run: $run_id"
fabro start "$run_id" --server "$SERVER"
fabro attach "$run_id" --server "$SERVER" || true
exec fabro wait "$run_id" --json --server "$SERVER"
