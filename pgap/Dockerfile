# PGAP HMM Annotation Container
# Runs HMMER hmmscan against the NCBI PGAP HMM library (hmm_PGAP.LIB)
# hmm_PGAP.LIB contains NCBIfam + TIGRfam models (~500 MB, much lighter than
# the full cwltool-based PGAP pipeline).
#
# Mount points:
#   /input/  — protein FASTA (.faa) from gene caller
#   /output/ — hmmscan outputs (pgap.domtblout, pgap.out)
#   /db/     — directory containing hmm_PGAP.LIB and hmm_PGAP.tsv
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    wget tar gzip make gcc g++ perl python3 python3-pip bc \
    && rm -rf /var/lib/apt/lists/*

# Install HMMER 3.4
RUN cd /tmp && \
    wget -q http://eddylab.org/software/hmmer/hmmer-3.4.tar.gz && \
    tar -xzf hmmer-3.4.tar.gz && \
    cd hmmer-3.4 && \
    ./configure && make -j$(nproc) && make install && \
    cd / && rm -rf /tmp/hmmer-3.4*

RUN mkdir -p /input /output /db

COPY entrypoint.sh /usr/local/bin/run
RUN chmod +x /usr/local/bin/run

ENTRYPOINT ["/usr/local/bin/run"]
