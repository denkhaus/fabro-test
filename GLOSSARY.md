# Glossary

The working vocabulary of the fabro-test bench. One term, one meaning. The
platform's own vocabulary (work item, claim, lane, run channel, …) lives in
`../fabro/GLOSSARY.md` and is used here verbatim.

## Bench adapter library

The bench's single interface to the fabro server and the forge: server
resolution, the local-server guard, the auth header, the gh shape
normalization, the run lifecycle, the events walk, and the landing. Lives
in `scripts/lib/bench.nu`. Drivers (`workbench.nu`, `land.nu`,
`publish-bridge.nu`, `run-mini.nu`) and satellites are thin callers — an
adapter fix lands once and reaches every caller.

- Not a **platform component**: it asserts nothing about the platform; it
  is bench-local plumbing.
- Not a **seam for platform behaviour**: probes vary the platform behind
  the bench's doors; the library only speaks to it.

## Landing

The PR dance that carries bench changes onto the protected main: branch
resume-or-cut from origin/main, force-with-lease push, open-PR reuse, wait
for checks to REPORT (the red prestate is by design; green is never
demanded), squash merge with --admin, local main resync. Lives as `land-pr`
in the bench adapter library.

- Not a **run landing**: the engine's own publish path for run snapshots
  (`fabro/run/<id>` branches, engine-created run PRs) is platform work.
- The landing is **resumable**: a prior landing that died after committing
  continues instead of duplicating or resetting.

## Satellite

A facet script that one driver sources and another drives standalone (the
retry-latest facet, probe-45). A satellite carries its own dependencies —
it imports the bench adapter library itself; no sourcing driver supplies
context under the table.

- Not a **probe**: a probe is a full workflow rig under `.fabro/workflows/`
  fired through the bench; a satellite drives one facet from `scripts/`.
