# InterProScan ships x86_64 binaries only; force amd64 emulation on ARM64 hosts
FROM --platform=linux/amd64 eclipse-temurin:11-jre-jammy

# ── Minimal runtime support ───────────────────────────────────────────────────
# InterProScan ships its own binaries (hmmer, coils, etc.) inside data/.
# This container only needs to provide Java 11 and Python 3 (for helper scripts).
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        perl \
        libgomp1 \
        libgcc-s1 \
    && rm -rf /var/lib/apt/lists/*

# ── Entrypoint ────────────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/run
RUN chmod +x /usr/local/bin/run

# /input/  — protein FASTA (.faa)
# /output/ — InterProScan outputs
# /db/     — full InterProScan installation (<root>/db/interpro/)
#            contains interproscan.sh + data/ (populated by setup/databases.sh)
RUN mkdir -p /input /output /db

ENTRYPOINT ["/usr/local/bin/run"]
