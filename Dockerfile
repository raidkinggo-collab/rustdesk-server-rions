# Build a patched hbbs that performs the secure handshake for signed-in (>=1.4.1)
# clients (rustdesk/rustdesk#16691). Without it, clients logged in to the API account
# fail with "Failed to secure tcp: deadline has elapsed".
#
# The official rustdesk-server image is a scratch/musl base, so a glibc hbbs cannot run
# on it ("exec /usr/bin/hbbs: no such file or directory"). A musl build pulls in
# openssl-sys which has no musl openssl here. So instead ship hbbs on a thin glibc
# base (debian-slim). hbbr keeps running from the official image in docker-compose, so
# this image only needs to provide the patched hbbs.
FROM rust:1.88-bookworm AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
        git patch build-essential cmake pkg-config libssl-dev protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone --depth 1 --recursive https://github.com/rustdesk/rustdesk-server.git .
COPY patches/0001-secure-handshake-for-signed-in-clients.patch /tmp/patch.patch
# Upstream drifts (line offsets + a context line like collections::{HashMap, VecDeque});
# all removal lines still match, so fuzzy patch applies cleanly where strict git apply won't.
RUN patch -p1 --fuzz=3 < /tmp/patch.patch
RUN cargo build --release --bin hbbs
# cargo hardlinks target/release/hbbs to deps/hbbs-<hash> (nlink=2). buildkit COPY of a
# hardlink emits an empty hardlink entry (32-byte layer, no data) when the link target
# isn't also copied, so /usr/bin/hbbs ends up empty -> "exec: no such file or directory".
# Copy to a fresh regular file (nlink=1) first, then COPY that.
RUN set -eux; cp /src/target/release/hbbs /hbbs.bin; test -s /hbbs.bin; ls -la /hbbs.bin

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
        libssl3 ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /hbbs.bin /usr/bin/hbbs
WORKDIR /root
# No ENTRYPOINT: docker-compose passes `command: hbbs -k _`, resolved via PATH.
