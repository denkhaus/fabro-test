#!/usr/bin/env nu
# Single-facet driver: the retry-latest facet ALONE (the compositional
# gate rule — never rerun the full bench to see one facet). Carries the
# three workbench-scope dependencies the facet satellite expects.
#
#   FABRO_SERVER=http://127.0.0.1:32276 nu scripts/drive-retry-latest-facet.nu

def server []: nothing -> string { $env.FABRO_SERVER? | default 'http://127.0.0.1:32276' }

def auth-header []: nothing -> record {
    let s = (open ~/.fabro/auth.json | get servers | get -o (server))
    let token = ($s | get -o token | default ($s | get -o access_token | default ''))
    { Authorization: $"Bearer ($token)" }
}

const FABRO = ('~/.fabro/bin/fabro' | path expand)

source retry-latest-facet.nu

def main []: nothing -> nothing {
    let row = (retry-latest-facet $"single-(date now | format date '%m%d-%H%M%S')")
    print ($row | table --index false)
    if not $row.ok { exit 1 }
}
