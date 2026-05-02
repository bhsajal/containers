FROM python:3.11-slim

# ── System dependencies (ncbi-blast+ provides rpsblast) ──────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        ncbi-blast+ \
    && rm -rf /var/lib/apt/lists/*

# ── COGclassifier v2 ──────────────────────────────────────────────────────────
RUN pip install --no-cache-dir cogclassifier

# ── Entrypoint ────────────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/run
RUN chmod +x /usr/local/bin/run

# /input/  — protein FASTA (.faa)
# /output/ — COGclassifier output directory
# /db/     — COG database (<root>/db/cog/)
RUN mkdir -p /input /output /db

ENTRYPOINT ["/usr/local/bin/run"]
