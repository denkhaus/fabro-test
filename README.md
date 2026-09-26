# fabro-test — LLM-Testline fuer Fabro-Workflows

Zweck: Facetten der Fabro-Cutover-Linie **lokal** (Docker-Sandbox) gegen ein
echtes Mini-Repo und echte (billige) LLM-Aufgaben testen — bevor auf
mirtuell.net deployt wird. Ein Run dauert wenige Minuten, nicht 20+.

## Regeln
- Eine Facette pro Test; ein Seed pro Run (eine Mini-Aufgabe, wenige Minuten).
- Seeds sind mini: eine Funktion, ein Fix, ein Testfall — am besten in
  `src/` + `tests/` ohne Build-Toolchain (python3-stdlib only).
- Modell: zai glm-4.7 (non-reasoning, billig). Kein reasoning_effort noetig.
- Tracker: `.seeds/issues.jsonl` (git-nativ, JSONL). Prefix `fabro-test-`.

## Workflow `mini` (Slim-Port von develop)
tracker_guard -> planner -> claim_check -> implementer -> tester ->
evidence -> reviewer -> closeout -> exit, mit Cycle-Guards
(`nodes.<stage>.generation >= 3` -> Deadlock-Exit).

Getestete Facetten:
1. `Contract::Schema` context_updates-Spread (Planner-File-Schema)
   -> `stdin_source`-Konsument (claim_check/closeout)   [c5a0-Seam]
2. Broad-Write-Envelope: Implementer fs_write UNSET, fs_hide verengt
3. Read-only-Reviewer: tools-Allowlist + fs_write=""
4. Command-Stages mit stdin_source + output_schema="routing"
5. Gate (python3 unittest), Evidence (git diff), Cycle-Guards
6. PR-Pipeline: run_branch push, squash-merge, auto-merge, PR-Titel-Modell

## Lokaler Lauf
```sh
# 1. Server (einmal):  fabro server start
# Einzelprobe:         just probe probe-06-guards   # eine Facette, keine volle Bench
# 2. Run:              ./scripts/run-mini.sh [--goal 'implement fabro-test-xxxx']
fabro create mini --environment test-local --json --server http://127.0.0.1:32276
fabro start  <run_id> --server http://127.0.0.1:32276
fabro wait   <run_id> --json --server http://127.0.0.1:32276
```
Env: `ZAI_API_KEY` (LLM), `GITHUB_TOKEN` (Forge: clone/push/PR).

## Seeds anlegen
Eine Zeile pro Seed in `.seeds/issues.jsonl`:
`{"id":"fabro-test-0001","title":"...","status":"open","type":"task",
  "priority":1,"createdAt":"...","updatedAt":"...","description":"..."}`
