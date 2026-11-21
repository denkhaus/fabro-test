---
name: iterate
description: "Evaluate an architecture review's results: file Strong candidates as seeds, enrich same-topic seeds with Worth-exploring evidence, record the rest in mulch, then close with retro. Use after an architecture review produced candidates, or when the user says iterate / auswerten."
---

# Iterate

Turn an architecture review's candidates into standing knowledge, then close the session. Every candidate carries a **strength** — Strong, Worth exploring, Speculative — and the strength decides the **disposition**:

| Strength        | Disposition                                  |
| --------------- | -------------------------------------------- |
| Strong          | **file** — one seed (work item) per candidate |
| Worth exploring | **enrich** a same-topic seed, else **record** |
| Speculative     | **record** in mulch                           |

## 1. Collect the work list

Take the candidates from the session's review — the HTML report, the candidate cards in the conversation, or both. One row per candidate: title, strength, files, evidence. A candidate that grilling reshaped carries its reshaped form and the session date. Every candidate the review produced lands on the list.

Done when: every candidate from the review is on the list with its strength.

## 2. File the Strong candidates

One seed per Strong candidate, filed as a work item on the central tracker. This repo's `docs/agents/issue-tracker.md` owns the canonical forms; the default stack:

    echo "$body" | fabro work --server https://mirtuell.net create --project fabro-proof --title "<candidate>" --body-file -

- Body: problem, solution, files, evidence (report path, line refs), review date. Bodies travel via stdin — that is the tracker's guardrail.
- File unlaned; lanes are the human's move (`lane:loop` is the typical home for bench-surface items).

Done when: every Strong candidate reports an item key (`denkhaus/work#N`).

## 3. Enrich same-topic seeds (Worth exploring)

Search the tracker for seeds on the candidate's topic first:

    fabro work --server https://mirtuell.net list --project fabro-proof --query "<topic terms>"

- **Seed found** → enrich: `show` the item, append an `## Evidence (arch review <date>)` section to the body (problem, files, report pointer), then `update --body-file -`. Append — the body is the item's memory, so existing text stays untouched.
- **No seed** → record (step 4).

Done when: every Worth-exploring candidate sits either inside a seed body or in mulch — nothing lives only in the report.

## 4. Record the rest in mulch

Speculative candidates and unseeded Worth-exploring knowledge become expertise records in the `architecture` domain:

    mulch init    # only when .mulch/ is missing
    mulch record architecture --type <decision|pattern|failure> \
      --title "<candidate>" \
      --rationale "<why no seed yet>" \
      --content "<problem — solution — files>" \
      --files "<comma-separated paths>"

Type guide: a candidate rejected with a load-bearing reason is `decision`; a suspected-but-unproven shape is `pattern`; friction evidence awaiting a seed is `failure`. When all records are in, `mulch sync` validates, stages, and commits — IN REPOS WITH PROTECTED MAIN, replace `mulch sync` with `mulch validate` + a landing of `.mulch/` through the repo's own PR dance (a direct commit never reaches main; the skill's sync step assumed a writable branch).

Done when: every recorded candidate reports a record id and `mulch sync` ran clean.

## 5. Close with retro

Every iterate run ends the session with the `retro` skill — dispositions filed first, then the session itself is reviewed.
