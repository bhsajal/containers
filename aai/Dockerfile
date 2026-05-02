FROM --platform=linux/amd64 python:3.9-slim

# ── AAI container ─────────────────────────────────────────────────────────────
# CompareM (Donovan Parks, dparks1134/CompareM) — established AAI tool for
# prokaryotic genomics, same author as CheckM and GTDB-Tk.
# Computes Average Amino Acid Identity (AAI) from protein FASTA (.faa) files
# using DIAMOND internally. Works for highly diverse organisms (no 80% cutoff).
#
# Reference: Parks DH, et al. (2017) CheckM: assessing the quality of microbial
#            genomes recovered from isolates, single cells, and metagenomes.
#            Genome Research, 25(7):1043-1055.
#
# Runtime interface:
#   docker run --rm \
#     -v <rasttk_output_dir>:/input:ro \
#     -v <aai_output_dir>:/output:rw \
#     annotation/aai:latest \
#     [--threads N] [--top-n N]
#
# The entrypoint:
#   1. Collects all .faa files from /input/<organism>/gene_calls/
#   2. Runs comparem aai_wf on the protein directory
#   3. Writes /output/aai_results.tsv   (raw CompareM pairwise AAI)
#   4. Writes /output/closest_organisms.tsv  (top-N per organism)
# ─────────────────────────────────────────────────────────────────────────────

LABEL maintainer="annotation-pipeline"
LABEL description="AAI — CompareM all-vs-all for prokaryotic genomes"
LABEL version="1.0"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        wget \
        diamond-aligner \
    && rm -rf /var/lib/apt/lists/*

# Install CompareM (latest stable) and pandas
RUN pip install --no-cache-dir comparem pandas

RUN mkdir -p /container/scripts /input /output /tmp/faa_pool

COPY scripts/ /container/scripts/

RUN chmod +x /container/scripts/entrypoint.sh

WORKDIR /container

ENTRYPOINT ["/container/scripts/entrypoint.sh"]
