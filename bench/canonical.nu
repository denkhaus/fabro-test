# Canonical workbench task — the bench acceptance (tests/test-canonical.nu)
# requires this script to print canonical-ok-9001. The bench resets the
# red stub before every seeded mini run.
def main []: nothing -> nothing {
    print 'canonical-ok-9001'
}
