FROM condaforge/miniforge3:latest

RUN conda install -y -c conda-forge -c bioconda diamond python=3.11 \
    && conda clean -afy

COPY entrypoint.sh /usr/local/bin/run
RUN chmod +x /usr/local/bin/run

RUN mkdir -p /input /output /db

ENTRYPOINT ["/usr/local/bin/run"]
