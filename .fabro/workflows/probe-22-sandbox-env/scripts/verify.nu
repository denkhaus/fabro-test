#!/usr/bin/env nu
# probe-22 verify: the capture files exist and are non-empty; the
# diagnostic digest is echoed into the run log (the bench asserts only the
# capture completed — the VALUES are evidence for fabro-114c).
const OUT = '/tmp/probe22'

def main []: nothing -> nothing {
    for f in [env.txt gitconfig.txt identity.txt checkpoints.txt] {
        let path = $"($OUT)/($f)"
        if not ($path | path exists) { print -e $"verify: missing ($f)"; exit 1 }
        if ((open --raw $path) | str trim | is-empty) { print -e $"verify: empty ($f)"; exit 1 }
    }
    print $"IDENTITY-PROBE: (open --raw $"($OUT)/identity.txt" | str trim | str replace --all '\n' ' ; ')"
    let cfg = (open --raw $"($OUT)/gitconfig.txt" | lines | where {|l| $l =~ '(?i)user\.|safe\.'} | str join ' ; ')
    print $"GIT-CONFIG-RELEVANT: ($cfg)"
    let cps = (open --raw $"($OUT)/checkpoints.txt" | lines | first 4 | str join ' ; ')
    print $"CHECKPOINT-IDENTITIES: ($cps)"
    let digest = (open --raw $"($OUT)/env.txt" | lines | where {|l| $l =~ '^(FABRO|PETRI|GIT_|GITCONFIG|DOCKER|HOME|USER)'} | str join ' ; ')
    print $"ENV-DIGEST: ($digest)"
    {preferred_next_label: 'Env captured'} | to json --raw | print
}
