#!/usr/bin/env nu
# Claim-contract gate: exit 0 iff stdin carries a non-empty seed id.
# ^cat, not `input`: this nu build surfaces piped stdin only
# to externals (`input` fails closed with an I/O error here).
let seed_id = (^cat | str trim)
if ($seed_id | is-empty) {
    print -e "claim contract failed: current_seed_id is empty"
    exit 1
}
print $"claim ok: ($seed_id)"
