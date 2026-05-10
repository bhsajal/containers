# tmhmm.py — MIT reimplementation of TMHMM2 (fully redistributable)
# Predicts transmembrane helices in prokaryotic and eukaryotic proteins
FROM python:3.9-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir "numpy<1.24" "Cython<3" \
    && pip install --no-cache-dir "tmhmm.py"

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
