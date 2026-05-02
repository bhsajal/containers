FROM ubuntu:22.04

# ── System dependencies ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        libssl-dev \
        libdb5.3 \
    && rm -rf /var/lib/apt/lists/*

# ── BV-BRC CLI (includes rast-process-genome, rast-export-genome, p3-scripts) ─
RUN wget -q \
        https://github.com/BV-BRC/BV-BRC-CLI/releases/download/1.040/bvbrc-cli-1.040.deb \
        -O /tmp/bvbrc.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/bvbrc.deb \
    && rm /tmp/bvbrc.deb \
    && rm -rf /var/lib/apt/lists/*

# ── Entrypoint ────────────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/run
RUN chmod +x /usr/local/bin/run

# ── Runtime mounts (populated at runtime, not bundled) ───────────────────────
# /input/  — genome FASTA files
# /output/ — annotation outputs
# /db/     — SEED subsystem database (<root>/db/rasttk/)
RUN mkdir -p /input /output /db

ENTRYPOINT ["/usr/local/bin/run"]
