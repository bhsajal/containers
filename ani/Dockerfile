FROM --platform=linux/amd64 python:3.11-slim

# ── ANI container ─────────────────────────────────────────────────────────────
# fastANI v1.34 for all-vs-all Average Nucleotide Identity across prokaryotic
# genomes. Outputs a pairwise ANI matrix and per-organism closest-5 table.
#
# Runtime interface:
#   docker run --rm \
#     -v <rasttk_output_dir>:/input:ro \
#     -v <ani_output_dir>:/output:rw \
#     annotation/ani:latest \
#     [--threads N] [--top-n N]
#
# The entrypoint:
#   1. Collects all .fna files from /input/<organism>/gene_calls/
#   2. Runs fastANI all-vs-all
#   3. Writes /output/ani_results.tsv   (raw fastANI output, 5-col)
#   4. Writes /output/closest_organisms.tsv  (top-N per organism)
# ─────────────────────────────────────────────────────────────────────────────

LABEL maintainer="annotation-pipeline"
LABEL description="ANI — fastANI all-vs-all for prokaryotic genomes"
LABEL version="1.0"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        wget \
        unzip \
        libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Install fastANI v1.34 (pre-compiled static binary)
RUN wget -q https://github.com/ParBLiSS/FastANI/releases/download/v1.34/fastANI-Linux64-v1.34.zip \
    && unzip fastANI-Linux64-v1.34.zip \
    && mv fastANI /usr/local/bin/fastANI \
    && chmod +x /usr/local/bin/fastANI \
    && rm fastANI-Linux64-v1.34.zip

# Install Python dependencies
RUN pip install --no-cache-dir pandas

RUN mkdir -p /container/scripts /input /output

COPY scripts/ /container/scripts/

RUN chmod +x /container/scripts/entrypoint.sh

WORKDIR /container

ENTRYPOINT ["/container/scripts/entrypoint.sh"]
