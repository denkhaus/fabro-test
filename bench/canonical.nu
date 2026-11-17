# lint-nu: exempt — the deliberate red stub IS the prestate's task (the
# workbench mini-integration seed; the seeded mini run makes it green).
# Canonical workbench task — reset to this stub before every bench.
def main []: nothing -> nothing {
    # Stub: the bench seed replaces this with the required return value.
    error make {msg: "bench prestate stub"}
}
