#!/usr/bin/env bash
# Publish bridge v2 (until the engine publish step lands):
# 1. copy the run's snapshot repo out of the server volume (docker cp),
# 2. push the EXACT final commit as fabro/run/<id> (verify_remote_head
#    passes -> the server's own PR path works),
# 3. try `fabro pr create` (LLM title); fall back to gh PR + auto-merge
#    when structured output fails (known zai gap),
# 4. link the PR to the run when the gh fallback ran.
# Usage: scripts/publish-bridge.sh <RUN_ID>
set -euo pipefail
cd "$(dirname "$0")/.."

RID="${1:?usage: publish-bridge.sh <RUN_ID>}"
BRANCH="fabro/run/$RID"
SERVER="${FABRO_SERVER:-http://127.0.0.1:32276}"
FABRO="${FABRO:-$HOME/.fabro/bin/fabro}"

# Final commit from the run.diff record (paginated event walk via API).
SHA="$(python3 - "$RID" <<'PYEOF'
import json, sys, urllib.request
from pathlib import Path
rid = sys.argv[1]
server = "http://127.0.0.1:32276"
token = json.loads((Path.home() / ".fabro/auth.json").read_text())["servers"][server]["token"]
after = None
for _ in range(12):
    url = f"{server}/api/v1/runs/{rid}/events?limit=1000" + (f"&after={after}" if after else "")
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    data = json.load(urllib.request.urlopen(req)).get("data", [])
    if not data:
        break
    after = data[-1]["stream_seq"]
    for e in data:
        r = (e.get("item") or {}).get("record") or {}
        if r.get("kind") == "run.diff":
            print(r["head_sha"]); sys.exit(0)
sys.exit("no run.diff record in run events")
PYEOF
)"
echo "== bridge: run $RID final commit $SHA"

SNAP="/storage/scratch/$(date -u +%Y%m%d)-$RID/petri/snapshots/invocation-0-scope-0.git"
TMP="$(mktemp -d)/snap.git"
docker cp "fabro-fabro-1:$SNAP" "$TMP" >/dev/null
git --git-dir="$TMP" cat-file -t "$SHA^{commit}" >/dev/null

echo "== bridge: pushing exact final commit as $BRANCH"
git --git-dir="$TMP" push https://github.com/denkhaus/fabro-test.git \
    "$SHA:refs/heads/$BRANCH"
rm -rf "$(dirname "$TMP")"

echo "== bridge: creating PR (server path first)"
if "$FABRO" pr create "$RID" --model "${PR_MODEL:-glm-4.7}" --server "$SERVER"; then
    echo "== bridge: done (engine-created PR)"
    exit 0
fi
echo "   server PR path failed (structured-output gap?) -- gh fallback"

PR_URL="$(gh pr create -R denkhaus/fabro-test --base main --head "$BRANCH" \
    --title "Mini run $RID (bridge publish)" \
    --body "Run $RID work from the run snapshot at final commit $SHA. Bridge-created; engine PR generation unavailable.")"
gh pr merge --squash --auto "$PR_URL"
"$FABRO" pr link "$RID" "$PR_URL" --server "$SERVER"
echo "== bridge: done (gh fallback) -- $PR_URL"
