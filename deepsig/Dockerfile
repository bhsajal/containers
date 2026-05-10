# DeepSig — signal peptide predictor for prokaryotes (GPL-3, redistributable)
# https://github.com/BolognaBiocomp/deepsig
# Supports: GRAM- (gram-negative), GRAM+ (gram-positive), ARCH (archaea)
# Uses the official bolognabiocomp/deepsig image as base.
FROM bolognabiocomp/deepsig:latest

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
