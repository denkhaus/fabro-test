# fabro-test workbench — nu only, no bash scripts (user directive 2026-09-25)

default:
    @just --list

# One mini integration run (seed loop). Optional goal text names a seed.
run goal="":
    nu scripts/run-mini.nu {{goal}}

# Publish bridge for a finished run: snapshot push + PR + automerge + link.
publish rid:
    nu scripts/publish-bridge.nu {{rid}}

# Validate every workflow graph (full admission incl. @-file refs).
validate target="":
    @python3 scripts/validate_workflows.py {{target}}

# ONE probe without the full bench (no board clean, no mini/publish).
#   just probe probe-03-tools           # default expect from the workbench table
#   just probe probe-09-envelope-deny   # expects failed (envelope violation)
#   just probe mini                     # seed loop WITHOUT publish bridge
#   just probe probe-01-schema failed   # override expect
# Exit 1 on red. Known-red: probe-03-tools (fabro-1a41), probe-06-guards (fabro-51ad).
probe name expect="":
    nu scripts/workbench.nu probe {{name}} {{ if expect != "" { "--expect " + expect } else { "" } }}

# List available probe workflows.
probes:
    @nu -c 'ls .fabro/workflows | get name | to text'

# THE workbench: after every upstream merge. All probes + platform checks
# + mini integration with publish. Rot/Gruen-Tabelle; rot -> exit 1.
workbench:
    nu scripts/workbench.nu
