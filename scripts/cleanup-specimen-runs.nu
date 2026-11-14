#!/usr/bin/env nu
# One-shot board cleanup: delete the stranded specimen runs a crashed
# retry-latest drive left behind (the facet deletes its runs only on
# its success path).
def server []: nothing -> string { $env.FABRO_SERVER? | default 'http://127.0.0.1:32276' }

def auth-header []: nothing -> record {
    let s = (open ~/.fabro/auth.json | get servers | get -o (server))
    let token = ($s | get -o token | default ($s | get -o access_token | default ''))
    { Authorization: $"Bearer ($token)" }
}

def main [...ids: string]: nothing -> nothing {
    if ($ids | is-empty) { return }
    let body = ({ run_ids: $ids, force: true } | to json -r)
    let res = (http post --headers (auth-header) -t 'application/json' -e $"((server))/api/v1/runs/delete" $body)
    print ($res | to json -r)
}
