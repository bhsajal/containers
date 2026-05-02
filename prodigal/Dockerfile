FROM ubuntu:22.04

# ── System dependencies ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ── Prodigal static binary ────────────────────────────────────────────────────
RUN wget -q \
        https://github.com/hyattpd/Prodigal/releases/download/v2.6.3/prodigal.linux \
        -O /usr/local/bin/prodigal \
    && chmod +x /usr/local/bin/prodigal

# ── Entrypoint ────────────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/run
RUN chmod +x /usr/local/bin/run

RUN mkdir -p /input /output

ENTRYPOINT ["/usr/local/bin/run"]
