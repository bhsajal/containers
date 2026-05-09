FROM --platform=linux/amd64 python:3.11-slim

# ── Synteny analysis container ─────────────────────────────────────────────
# clinker — gene cluster comparison using pairwise protein alignments.
# Input:  GenBank (.gbk) files from RASTtk gene calls
# Output: interactive HTML plot, alignments CSV, similarity matrix, session JSON
#
# Runtime interface (Apptainer/Docker):
#   apptainer run --bind <rasttk_root>:/input:ro,<out_dir>:/output:rw \
#     synteny.sif --organism <name> --partners <A,B,C,D,E> [OPTIONS]
#
# The entrypoint:
#   1. Collects .gbk for the query organism + each partner from /input
#   2. Runs clinker producing: plot.html, alignments.csv, matrix.tsv, session.json
#   3. Post-processes alignments.csv → synteny_links.tsv (structured TSV)
# ──────────────────────────────────────────────────────────────────────────────

LABEL maintainer="annotation-pipeline"
LABEL description="Synteny analysis — clinker gene cluster comparison"
LABEL version="2.0"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install clinker and post-processing dependencies
RUN pip install --no-cache-dir clinker pandas

# Setup directories
RUN mkdir -p /container/scripts /input /output

COPY scripts/ /container/scripts/

RUN chmod +x /container/scripts/entrypoint.sh

WORKDIR /container

ENTRYPOINT ["/container/scripts/entrypoint.sh"]
