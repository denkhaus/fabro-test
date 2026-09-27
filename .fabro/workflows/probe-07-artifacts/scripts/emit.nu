#!/usr/bin/env nu
# artifact producer: write the payload the collector later uploads.
mkdir out
'probe-07 artifact payload\n' | save --force out/report.txt
print 'wrote out/report.txt'
