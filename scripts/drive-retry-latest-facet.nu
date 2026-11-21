#!/usr/bin/env nu
# Single-facet driver: the retry-latest facet ALONE (the compositional
# gate rule — never rerun the full bench to see one facet). Thin launcher:
# the satellite carries its own dependencies via scripts/lib/bench.nu.
#
#   nu scripts/drive-retry-latest-facet.nu      (server via FABRO_SERVER)

source retry-latest-facet.nu

def main []: nothing -> nothing {
    let row = (retry-latest-facet $"single-(date now | format date '%m%d-%H%M%S')")
    print ($row | table --index false)
    if not $row.ok { exit 1 }
}
