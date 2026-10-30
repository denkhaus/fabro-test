#!/usr/bin/env nu
# channel-probe (work#1073): drive the EXACT evidence.nu call shape
# (`fabro work --server <channel.sock> ...`) from inside the run
# sandbox and ASSERT every link of the chain:
#   1. the channel mount ran (FABRO_SERVER + handshake token in env)
#   2. the socket file reached the sandbox filesystem (the bind)
#   3. the serve enforces the handshake (403 without the token)
#   4. the serve accepts with the owning run's token (200)
#   5. the CLI connects and completes a work call (rc 0)
# The scoped project is fabro-proof: run channels grant work access to
# the run's scoping project only, and bench runs scope to the proof
# project (proof-ensure).
const SCOPED_PROJECT = 'fabro-proof'

def fail [what: string]: nothing -> nothing {
    print -e $"channel-probe: ($what)"
    exit 1
}

def main []: nothing -> nothing {
    let sock = ($env.FABRO_SERVER? | default '')
    let tok = ($env.FABRO_RUN_CHANNEL_TOKEN? | default '')
    if ($sock | is-empty) { fail 'FABRO_SERVER is not set — the channel mount did not run' }
    if ($tok | is-empty) { fail 'FABRO_RUN_CHANNEL_TOKEN is not set — the handshake token never reached the sandbox env' }
    print $"env: token-present=yes server=($sock)"

    if not ($sock | path exists) { fail $"socket ($sock) does not exist in the sandbox — the channel bind is broken (denkhaus/work#1073 class)" }
    print $"socket: ($sock) present"

    let no_token = (do { ^curl -s --max-time 5 --unix-socket $sock -o /dev/null -w '%{http_code}' http://fabro/health } | complete | get stdout | str trim)
    if $no_token != '403' { fail $"serve should refuse without the token, got ($no_token)" }
    print 'serve: 403 without token (handshake enforced)'

    let with_token = (do { ^curl -s --max-time 5 --unix-socket $sock -H $"x-fabro-run-channel-token: ($tok)" -o /dev/null -w '%{http_code}' http://fabro/health } | complete | get stdout | str trim)
    if $with_token != '200' { fail $"serve should accept the owning run's token, got ($with_token)" }
    print 'serve: 200 with the owning token'

    let bin = ($env.FABRO_BIN? | default 'fabro')
    let res = (do { ^$bin work --server $sock list --project $SCOPED_PROJECT --limit 1 --json } | complete)
    if $res.exit_code != 0 {
        print -e ($res.stderr | str trim | str substring 0..400)
        fail 'the work CLI over the channel failed (rc != 0)'
    }
    print 'cli: work list through the channel green'
    print 'channel-probe: all links green'
}
