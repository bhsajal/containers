# ── Scoring container (placeholder) ──────────────────────────────────────────
# Accepts labeled.tsv from stageD/labeling and will produce scores.tsv.
# Currently writes a pass-through placeholder — scoring logic TBD.
#
# Compatible with Docker (linux/amd64, linux/arm64) and Apptainer/Singularity.
# ─────────────────────────────────────────────────────────────────────────────
FROM python:3.11-slim

LABEL org.opencontainers.image.title="margie-scoring"
LABEL org.opencontainers.image.description="Scoring stage for the margie-annotation pipeline (placeholder)"
LABEL org.opencontainers.image.source="https://github.com/sajalbhattarai/containers"

RUN pip install --no-cache-dir pandas

COPY entrypoint.py /usr/local/bin/entrypoint.py
RUN chmod +x /usr/local/bin/entrypoint.py

ENTRYPOINT ["python3", "/usr/local/bin/entrypoint.py"]
