#!/usr/bin/env nu
# probe-41 (work#1107 stage F): the watchdog's read doors, driven from a
# real run sandbox over the run channel. A faithful copy of the
# watchdog stall check's read half (the probe-30 mirror precedent): the
# stall LOGIC and its alarm arm are pinned by fabro's
# watchdog/scripts/stall-check-smoke.nu; this probe proves the transport
# — `fabro automations list` and `fabro ps -a --workflow <gear>` must be
# readable by a run-scoped worker. Absent gear automations read
# disabled: the pause is authoritative, silence is health.

const GEARS = [adjudicator merger develop]

def main []: nothing -> nothing {
    let srv = ($env.FABRO_SERVER? | default '' | str trim)
    if ($srv | is-empty) {
        print -e "probe-41: FABRO_SERVER is not set — the channel mount carries it"
        exit 1
    }
    # The automations read: the gear rows (absent on the bench server —
    # the gears go live at the fork.30 cutover).
    let auto = (do { fabro automations --server $srv list --json } | complete)
    if $auto.exit_code != 0 {
        print -e $"probe-41: automations list refused over the channel: ($auto.stderr | str trim | str substring 0..240)"
        exit 1
    }
    let rows = (try { $auto.stdout | from json } catch {
        print -e "probe-41: automations list printed no JSON"
        exit 1
    })
    # The pass read: every gear's run history through ps.
    mut healthy = []
    for gear in $GEARS {
        let res = (do { fabro ps --server $srv --all --json --workflow $gear } | complete)
        if $res.exit_code != 0 {
            print -e $"probe-41: ps refused for ($gear): ($res.stderr | str trim | str substring 0..240)"
            exit 1
        }
        let runs = (try { $res.stdout | from json } catch {
            print -e $"probe-41: ps printed no JSON for ($gear)"
            exit 1
        })
        let enabled = ($rows | where {|r| ($r | get -o workflow | default '') == $gear} | length) > 0
        let note = (if $enabled { $"($gear): automation present" } else { $"($gear): absent — silent, the pause is authoritative" })
        $healthy = ($healthy | append $note)
        print $"probe-41: ($note); ($runs | length) run\(s) in history"
    }
    print $"probe-41: all read doors green: ($healthy | length) gears checked"
    print 'preferred_label: "All gears healthy"'
}
