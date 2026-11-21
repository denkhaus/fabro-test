# Domain Docs

How the engineering skills should consume this repo's domain documentation
when exploring the codebase. Layout: **single-context**.

## Where things live

- `GLOSSARY.md` (repo root) — the canonical glossary. NOT CREATED YET:
  `/domain-modeling` (reached via `/grill-with-docs` and
  `/improve-codebase-architecture`) creates it lazily when terms
  actually get resolved. Proceed without it until then.
- `docs/adr/` — local decision record, also lazy. The GOVERNING platform
  ADRs live in the sibling repo: `../fabro/docs/adr/` (ADR-0032 central
  work-item tracker, ADR-0033 English-only artifacts, ADR-0039
  adjudicator/merger doors, ADR-0042 run-built environment images, …).
  Cite platform decisions by number and repo; bench-local decisions
  land in local `docs/adr/` once made.
- `../fabro/GLOSSARY.md` — the platform vocabulary (work item, claim,
  lane, run channel, environment image, adjudicator, merger, …). The
  bench speaks this language; use it before inventing new terms.

## Before exploring, read these

- `../fabro/GLOSSARY.md` (the binding vocabulary).
- The ADR in `../fabro/docs/adr/` that owns the area you touch.
- Local `GLOSSARY.md` / `docs/adr/` when they exist.

If a file you'd expect doesn't exist, proceed silently. Don't flag its
absence; don't suggest creating it upfront.

## Use the glossary's vocabulary

When your output names a domain concept (in a proof item title, a
refactor proposal, a hypothesis, a test name), use the term as defined
in the glossary (local `GLOSSARY.md`, else `../fabro/GLOSSARY.md`).
Don't drift to synonyms the glossary explicitly avoids. If the concept
you need isn't in the glossary yet, that's a signal: either you're
inventing language the project doesn't use (reconsider) or there's a
real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR (local or `../fabro`),
surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders), but worth reopening because…_
