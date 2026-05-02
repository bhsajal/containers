FROM condaforge/miniforge3:latest

RUN conda install -y -c bioconda -c conda-forge hmmer python pandas \
    && conda clean -afy

COPY entrypoint.sh /usr/local/bin/run
RUN chmod +x /usr/local/bin/run

# /input/  — protein FASTA (.faa)
# /output/ — hmmscan output
# /db/     — TIGRFAMs database (<root>/db/tigrfam/)
RUN mkdir -p /input /output /db

ENTRYPOINT ["/usr/local/bin/run"]
