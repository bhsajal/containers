# TMbed — deep learning transmembrane segment and signal peptide predictor
# License: Apache-2.0 (https://github.com/BernhoferM/TMbed)
# The ProtT5-XL-U50 encoder model (~2.25 GB) is downloaded to /models on first use.
# Mount a persistent host directory to /models so the download only happens once.
FROM python:3.9-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        git build-essential ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu \
    && pip install --no-cache-dir git+https://github.com/BernhoferM/TMbed.git

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/run_tmbed.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
