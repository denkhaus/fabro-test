#!/usr/bin/env nu
# probe-22 capture (fabro-114c): dump the run sandbox's full environment,
# the effective git config with its origins, the ambient identity of a
# scratch commit with NOTHING configured, and the run branch's checkpoint
# identities as the sandbox sees them. Files land in /tmp/probe22 for the
# verify stage; the verify stage echoes the digest into the run log.
const OUT = '/tmp/probe22'

def main []: nothing -> nothing {
    let workspace = $env.PWD
    mkdir $OUT
    env | sort | to text | save --raw $"($OUT)/env.txt"

    let cfg = (do { git config -l --show-origin } | complete)
    $cfg.stdout | save --raw $"($OUT)/gitconfig.txt"

    # Scratch commit with nothing configured: as whom does git land it
    # here? This is the 114c datum — every ambient identity source
    # (engine-injected env, image config, daemon-side config) shows up.
    mkdir $"($OUT)/scratch"
    cd $"($OUT)/scratch"
    let init = (do { git init --quiet } | complete)
    let commit = (do { git commit --quiet --allow-empty -m probe-22 } | complete)
    let ident = (do { git log -1 --format='%an|%ae|%cn|%ce' } | complete)
    [
        $"init exit: ($init.exit_code)"
        $"commit exit: ($commit.exit_code) stderr: ($commit.stderr | str trim | str substring 0..300)"
        $"identity: ($ident.stdout | str trim)"
    ] | str join "\n" | save --raw $"($OUT)/identity.txt"

    # The run branch's own commit identities (engine checkpoints of THIS
    # probe run), as visible from inside the sandbox workspace.
    cd $workspace
    let cps = (do { git log -n 8 --format='%an|%ae|%cn|%ce' } | complete)
    $cps.stdout | save --raw $"($OUT)/checkpoints.txt"
}
