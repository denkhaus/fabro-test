FROM ubuntu:24.04
# The repo-declared run environment (ADR-0042): the engine cooks this at
# run init from the checkout. The workbench probes are pure-nu since
# fabro-test 088f25a (2026-09-27) and five of them drive `fabro` /
# `mulch` INSIDE the sandbox (channel/evidence chain, observation CLI,
# adjudicator/merger/watchdog simulators, work#1070 cutover) — the cook
# must carry nushell and both binaries or those stages die 127
# ("command not found", diagnosed in the fork.35 window 2026-11-14).
# Binaries follow the line's Dockerfile.toolchain pattern (mulch/seeds):
# version-pinned ARGs, musl-static release artifacts, checksum-verified.
# User decision 2026-11-14: the fabro CLI ships as a GitHub release
# binary; pin bumps are deliberate commits (never floating latest — a
# curl-latest layer would serve a stale binary from docker's cache).

ARG FABRO_VERSION=0.362.0-fork.35
ARG FABRO_SHA256_X86_64=a4c594e04ece80e444f93e2b09b17e068cd783c0aeff8faaabcf27b38e06d824
ARG FABRO_SHA256_AARCH64=pending
ARG MULCH_VERSION=0.1.0
ARG MULCH_SHA256_X86_64=b3017b4ab6303708153c917a85cce8be2fe342778cf19069fc352d3784daa509
ARG MULCH_SHA256_AARCH64=a4739b8f82a2750321b876f9572f4271c23845ab301bbdb7c701b8a5cc270aac

RUN apt-get update \
 && apt-get install -y --no-install-recommends git python3 ca-certificates curl xz-utils \
 && rm -rf /var/lib/apt/lists/* \
 && arch="$(uname -m)" \
 && curl -fsSL "https://github.com/nushell/nushell/releases/download/0.116.1/nu-0.116.1-${arch}-unknown-linux-musl.tar.gz" \
    | tar -xz --strip-components=1 -C /usr/local/bin "nu-0.116.1-${arch}-unknown-linux-musl/nu" \
 && nu --version

# fabro CLI: the static musl release binary (the host-release artifact),
# exactly the production client for the stack the bench drives against.
RUN set -eux; \
    case "$(uname -m)" in \
        x86_64) triple=x86_64-unknown-linux-musl; sha="${FABRO_SHA256_X86_64}";; \
        aarch64) triple=aarch64-unknown-linux-musl; sha="${FABRO_SHA256_AARCH64}";; \
        *) echo "unsupported arch $(uname -m)"; exit 1;; \
    esac; \
    curl -fsSL "https://github.com/denkhaus/fabro/releases/download/${FABRO_VERSION}/fabro-${FABRO_VERSION}-${triple}.tar.gz" -o /tmp/fabro.tgz; \
    if [ "$sha" = "pending" ]; then echo "no checksum pinned for ${triple} yet"; exit 1; fi; \
    echo "${sha}  /tmp/fabro.tgz" | sha256sum -c -; \
    tar -xzf /tmp/fabro.tgz -C /usr/local/bin fabro; \
    chmod 0755 /usr/local/bin/fabro; \
    rm /tmp/fabro.tgz; \
    fabro --version

# mulch (work#1070, ADR-0023 cutover): identical to the line's
# Dockerfile.toolchain block — same version, same checksums.
RUN set -eux; \
    case "$(uname -m)" in \
        x86_64) triple=x86_64-unknown-linux-musl; sha="${MULCH_SHA256_X86_64}";; \
        aarch64) triple=aarch64-unknown-linux-musl; sha="${MULCH_SHA256_AARCH64}";; \
        *) echo "unsupported arch $(uname -m)"; exit 1;; \
    esac; \
    curl -fsSL "https://github.com/denkhaus/mulch/releases/download/v${MULCH_VERSION}/mulch-${MULCH_VERSION}-${triple}.tar.gz" -o /tmp/mulch.tgz; \
    echo "${sha}  /tmp/mulch.tgz" | sha256sum -c -; \
    tar -xzf /tmp/mulch.tgz -C /usr/local/bin mulch; \
    chmod 0755 /usr/local/bin/mulch; \
    rm /tmp/mulch.tgz; \
    mulch --version
WORKDIR /workspace
