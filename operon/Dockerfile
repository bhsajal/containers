# ── Operon Prediction container ───────────────────────────────────────────────
# Clones UniOP (https://github.com/hongsua/UniOP) at build time and installs
# its Python dependencies.  Internet access is required at build time.
#
# Runtime interface:
#   docker run ... annotation/operon:latest \
#     -i /input/<organism>.faa \
#     -g /input/<organism>.gff \
#     -o /output [-t THREADS]
#
# The entrypoint:
#   1. Converts RAST GFF3 + FAA → Prodigal-style FAA (needed by UniOP)
#   2. Runs UniOP → writes uniop.pred and uniop.operon to /output
#   3. Also writes the converted uniop_input.faa to /output (used by process.py)
# ──────────────────────────────────────────────────────────────────────────────
FROM python:3.11-slim

LABEL maintainer="annotation-pipeline"
LABEL description="Operon prediction — UniOP (intergenic-distance model)"
LABEL version="1.0"

ENV DEBIAN_FRONTEND=noninteractive
ENV UNIOP_HOME=/opt/UniOP

RUN apt-get update && apt-get install -y \
    bash \
    ca-certificates \
    git \
    prodigal \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/hongsua/UniOP.git "$UNIOP_HOME" && \
    python -m pip install --no-cache-dir numpy pandas scikit-learn

RUN mkdir -p /container/scripts /container/input /container/output

COPY scripts/ /container/scripts/

RUN chmod +x /container/scripts/entrypoint.sh

WORKDIR /container

ENTRYPOINT ["/container/scripts/entrypoint.sh"]
