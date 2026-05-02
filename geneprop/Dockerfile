# ── Genome Properties container ─────────────────────────────────────────────
# This container is intentionally minimal: all assignment logic is handled
# by process.py on the host, which reads the TIGRFAMs domtblout from the
# tigrfam stage output and the genome-properties flatfiles from /db.
# The container itself is a no-op pass-through that satisfies the pipeline
# interface (creates /output and exits 0).
# ──────────────────────────────────────────────────────────────────────────────
FROM condaforge/miniforge3:latest

RUN conda install -y -c conda-forge -c bioconda python=3.11 pandas \
    && conda clean -afy

COPY entrypoint.sh /usr/local/bin/run
RUN chmod +x /usr/local/bin/run

RUN mkdir -p /input /output /db

ENTRYPOINT ["/usr/local/bin/run"]
