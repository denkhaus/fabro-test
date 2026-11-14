FROM ubuntu:24.04
# The repo-declared run environment (ADR-0042): the engine cooks this at
# run init from the checkout, and the workbench probes execute nu since
# the pure-nu port (fabro-test 088f25a, 2026-09-27) — the sandbox MUST
# carry nushell on PATH or every command stage dies 127 ("nu: command
# not found", bench rounds since the sprint-84 inert reconcile
# 2026-11-11; diagnosed in the fork.35 window 2026-11-14). The version
# pins to the harness nu (0.116.1, the P1 parity facet's pin); python3
# stays for the pre-port stragglers.
RUN apt-get update \
 && apt-get install -y --no-install-recommends git python3 ca-certificates curl xz-utils \
 && rm -rf /var/lib/apt/lists/* \
 && arch="$(uname -m)" \
 && curl -fsSL "https://github.com/nushell/nushell/releases/download/0.116.1/nu-0.116.1-${arch}-unknown-linux-musl.tar.gz" \
    | tar -xz --strip-components=1 -C /usr/local/bin "nu-0.116.1-${arch}-unknown-linux-musl/nu" \
 && nu --version
WORKDIR /workspace
