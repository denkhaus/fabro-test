#!/usr/bin/env nu
# The agent session must have survived a prompt with two path-like
# /tokens (fabro-3fce: pebble's skill expansion fired on harness input
# and killed the session with skill_missing).
print "verify: the mention stage ran"
{preferred_next_label: 'Skills ok'} | to json --raw | print
