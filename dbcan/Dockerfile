FROM condaforge/miniforge3:latest

# ── dbCAN v5 + DIAMOND (conda — ARM64 native binaries) ───────────────────────
RUN conda install -y -c conda-forge -c bioconda \
        dbcan \
        diamond \
    && conda clean -afy

# ── Entrypoint ────────────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/run
RUN chmod +x /usr/local/bin/run

# /input/  — protein FASTA (.faa)
# /output/ — dbCAN output directory  (native/ subdirectory created at runtime)
# /db/     — dbCAN database (<root>/db/dbcan/)
RUN mkdir -p /input /output /db

ENTRYPOINT ["/usr/local/bin/run"]
