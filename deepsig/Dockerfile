# DeepSig — signal peptide predictor for prokaryotes (GPL-3, redistributable)
# https://github.com/BolognaBiocomp/deepsig
# Supports: GRAM- (gram-negative), GRAM+ (gram-positive), ARCH (archaea)
FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir deepsig

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
