FROM condaforge/miniforge3:latest

# ── Install kofamscan + hmmer via conda ───────────────────────────────────────
RUN conda install -y -c conda-forge -c bioconda \
        kofamscan \
        hmmer \
        parallel \
    && conda clean -afy

# ── Entrypoint ────────────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/run
RUN chmod +x /usr/local/bin/run

# /input/  — protein FASTA (.faa)
# /output/ — KofamScan output
# /db/     — KEGG database: profiles/ + ko_list
RUN mkdir -p /input /output /db

ENTRYPOINT ["/usr/local/bin/run"]

