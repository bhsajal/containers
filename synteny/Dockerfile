FROM --platform=linux/amd64 python:3.11-slim

# ── Synteny analysis container ────────────────────────────────────────────────
# DIAMOND v2 for all-vs-all protein comparison across organisms.
# Python 3 with pandas/numpy for synteny block detection post-processing.
#
# Runtime interface:
#   docker run --rm \
#     -v <rasttk_output_dir>:/input:ro \
#     -v <synteny_native_dir>:/output:rw \
#     annotation/synteny:latest \
#     --organism <organism_name> [--threads N] [--min-identity N] [--min-coverage N]
#
# The entrypoint:
#   1. Builds gene_coords.tsv (once, from all GFF files in /input)
#   2. Builds combined DIAMOND database (once, from all FAA files in /input)
#   3. Runs DIAMOND blastp for the specified organism
#   4. Writes diamond_hits.tsv to /output/<organism>/
# ──────────────────────────────────────────────────────────────────────────────

LABEL maintainer="annotation-pipeline"
LABEL description="Synteny analysis — DIAMOND all-vs-all protein comparison"
LABEL version="1.0"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install DIAMOND v2.1.11
RUN wget -q https://github.com/bbuchfink/diamond/releases/download/v2.1.11/diamond-linux64.tar.gz \
    && tar xzf diamond-linux64.tar.gz \
    && mv diamond /usr/local/bin/diamond \
    && chmod +x /usr/local/bin/diamond \
    && rm diamond-linux64.tar.gz

# Install Python dependencies
RUN pip install --no-cache-dir pandas numpy

# Setup directories
RUN mkdir -p /container/scripts /input /output

COPY scripts/ /container/scripts/

RUN chmod +x /container/scripts/entrypoint.sh

WORKDIR /container

ENTRYPOINT ["/container/scripts/entrypoint.sh"]
