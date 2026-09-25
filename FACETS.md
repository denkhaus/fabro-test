# fabro-test Workbench — Facetten-Katalog

Zweck: Nach jedem Upstream-Merge (`just up` im fabro-Repo frischt Image+CLI)
laeuft `just workbench` hier: minimale Workflows testen jede Facette,
lokal im Docker, glm-4.7. Gruen → Deploy auf mirtuell. Rot → Seed/Fix VOR Deploy.

Regeln: 1 Facette = 1 Probe-Workflow, <=3 Stages, Stage-Timeouts,
Sandbox-Skripte in python3 (Env-Image buildpack-deps:noble hat kein nu),
Host-Skripte in nu. Budget: < 15 min und < 1 EUR pro Workbench-Lauf.

| # | Facette | Probe | Erwartung | Beweis |
|---|---------|-------|-----------|-------|
| 01 | Contract::Schema context_updates-Spread (c5a0) | probe-01-schema | stdin-Konsument liest den Schema-Wert | Run 5/6 (Session 2026-09-25) |
| 02 | Narrow-Write-Envelope (fs_write-Pin + Deny) | probe-02-envelope | erlaubte Datei da, verbotene fehlt | neu |
| 03 | Tools-Allowlist (read-only-Agent) | probe-03-tools | Leseaufgabe gelingt, Schreibversuch verweigert | neu |
| 04 | Run-Tools: fabro_run_create + wait (Child-Run) | probe-04-runtools | Kind-Run erstellt + succeeded | neu |
| 05 | Sandbox-Hooks (stage_complete) | probe-05-hooks | Journal-Eintrag im Run-Workspace | neu |
| 06 | Cycle-Guards (generation >= 3 -> Deadlock) | probe-06-guards | Run terminiert als Deadlock, nicht Endlosschleife | neu |
| 07 | Artifacts ([run.artifacts] include) | probe-07-artifacts | artifact.collected-Record in den Run-Events | neu |
| 08 | HITL/Interview: alle 5 Fragetypen (yes_no, confirmation, multiple_choice, multi_select, freeform) | probe-08-interview | jede Frage via API beantwortet, Run gruen | fabro-dbb4 (Vorbild) |
| 09a | Seeds-Loop komplett (mini + Publish-Bridge) | mini | Seed implementiert, PR squash-gemerged, Tracker zu | PRs #1/#2 |
| 09b | Write-Envelope verweigert ausserhalb des Scopes (Stage failt hart) | probe-09-envelope-deny | Run failed mit 'envelope violation' | Run 01M3D4FAS6WX0M |
| P1 | Server-API: health/models/environments | workbench (nu) | 200 + zai configured + env-Registry | smoke |
| P2 | Web: SPA-Index + Asset | workbench (nu) | Index referenziert Asset | smoke |
| P3 | Completions-Smoke (echter LLM-Call) | workbench (nu) | 1-Token-Antwort | neu |
| 03* | x.tools-Allowlist — BEKANNT ROT bis fabro-1a41 (Regression) | probe-03-tools | write_file muss verweigert werden | Run 01M3D6JZAX1YHB |

Pflege: neue Produkt-Bugs (rootprint-Fehlerbilder von mirtuell) landen als
Zeile hier + Probe + fabro-Seed, BEVOR irgendein Deploy laeuft.

Publish-Notiz: Facette 09 nutzt die Bridge (Snapshot-Push + gh-Fallback),
bis fabro-ac40 (Engine-Publish) sie ersetzt.
