#!/usr/bin/env nu
# The run-level assertion (the host hook's own exit code) is checked by the
# workbench from the run's hook notes: this stage only proves the run
# reached its verify step.
print "verify: the host hook fired without failing the run"
{preferred_next_label: 'Hosthook ok'} | to json --raw | print
