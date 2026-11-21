#!/usr/bin/env nu
# Bench adapter library interface test: the gh pr-list shape normalization
# against recorded fixtures. The drift class it pins: some gh builds answer
# a bare record for limit 1, others an array — three copies normalized it,
# the fourth (land.nu:80) parsed raw until the adapter library claimed it.
# Pure helpers only: no network, no fabro server, no gh binary.
use ../scripts/lib/bench.nu

def main [] {
    let array_form = "[{\"number\": 7, \"url\": \"https://example/pr/7\"}]"
    let record_form = '{"number": 7, "url": "https://example/pr/7"}'
    let empty_form = ''
    let garbage_form = 'not json at all'

    let array_norm = (bench gh-pr-normalize $array_form)
    let record_norm = (bench gh-pr-normalize $record_form)
    let empty_norm = (bench gh-pr-normalize $empty_form)
    let garbage_norm = (bench gh-pr-normalize $garbage_form)

    let checks = [
        ($array_norm == [{number: 7, url: "https://example/pr/7"}])
        ($record_norm == [{number: 7, url: "https://example/pr/7"}])
        ($empty_norm == [])
        ($garbage_norm == [])
    ]
    if ($checks | any {|c| not $c}) {
        print -e $"test-bench-lib: normalization fixture mismatch — array=($array_norm | to json -r) record=($record_norm | to json -r) empty=($empty_norm | to json -r) garbage=($garbage_norm | to json -r)"
        exit 1
    }
    print 'test-bench-lib: gh-pr-normalize fixtures ok (record wrapped, array passed, empty and garbage tolerated)'
}
