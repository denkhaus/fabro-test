#!/usr/bin/env bash
# Publish bridge for the mini line (until the engine publish step lands):
# reconstruct the run branch from base_sha + stored patch, push it, open
# a PR, squash-merge it, and link the PR to the run.
# Usage: scripts/publish-bridge.sh <RUN_ID>
set -euo pipefail
cd "$(dirname "$0")/.."

RID="${1:?usage: publish-bridge.sh <RUN_ID>}"
BRANCH="fabro/run/$RID"
SERVER="${FABRO_SERVER:-http://127.0.0.1:32276}"

echo "== bridge: fetching base+patch for $RID"
OUT="$(python3 scripts/bridge_fetch.py "$RID")"
BASE="$(printf '%s\n' "$OUT" | head -1)"
PATCH="$(printf '%s\n' "$OUT" | tail -n +2)"
echo "   base=$BASE patch_bytes=${#PATCH}"

git fetch origin --quiet
git rev-parse --verify "$BASE^{commit}" >/dev/null

echo "== bridge: reconstructing $BRANCH"
git checkout --quiet -B "bridge/$RID" "$BASE"
printf '%s\n' "$PATCH" | git apply --index -
git -c user.name=denkhaus -c user.email=denkhaus@users.noreply.github.com \
    commit --quiet -m "fabro($RID): mini bridge publish" -m "Fabro-Run: $RID"
git push --quiet origin "HEAD:refs/heads/$BRANCH"
git checkout --quiet main
git branch --quiet -D "bridge/$RID"

echo "== bridge: opening PR"
PR_URL="$(gh pr create -R denkhaus/fabro-test --base main --head "$BRANCH" \
    --title "Mini run $RID (bridge publish)" \
    --body "Reconstructed from run $RID checkpoint (bridge until engine publish lands). Seed work + tracker close.")"

echo "== bridge: squash-merging $PR_URL"
gh pr merge -R denkhaus/fabro-test --squash --delete-branch "$PR_URL"

echo "== bridge: linking PR to run"
~/.fabro/bin/fabro pr link "$RID" "$PR_URL" --server "$SERVER"

git pull --ff-only --quiet
echo "== bridge: done — main updated, PR linked: $PR_URL"
