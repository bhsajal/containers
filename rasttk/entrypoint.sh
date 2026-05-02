#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# RAST-TK / BV-BRC container entrypoint
# Installed at /usr/local/bin/run inside the container.
#
# No arguments or --help/-h  →  print usage and exit 0
# Any other arguments        →  exec rast-process-genome "$@"
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [[ $# -eq 0 || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'HELP_EOF'

RAST-TK / BV-BRC — Prokaryotic genome annotation via the SEED subsystem framework

USAGE
  rast-process-genome [OPTIONS]

KEY OPTIONS
  --input FILE             Input genome FASTA (.fna)
  --output-file FILE       Output annotated genome in RAST JSON format
  --scientific-name NAME   Organism scientific name  (e.g. "Escherichia coli K-12")
  --domain TEXT            Domain: Bacteria | Archaea  [default: Bacteria]
  --genetic-code INT       Genetic code table number   [default: 11]

EXPORT (run after rast-process-genome):
  rast-export-genome --input genome.json --type gff3         > genome.gff
  rast-export-genome --input genome.json --type protein_fasta > genome.faa
  rast-export-genome --input genome.json --type genbank       > genome.gbk

MOUNT POINTS (bind at runtime)
  /input/    Genome FASTA directory or file
  /output/   Output directory
  /db/       SEED subsystem database  (<root>/db/rasttk/)

EXAMPLE
  apptainer run --bind <input>:/input,<output>:/output,<db>:/db rasttk.sif \
    rast-process-genome \
      --input /input/genome.fna \
      --output-file /output/genome.json \
      --scientific-name "Organism name" \
      --domain Bacteria

OUTPUTS (after export)
  genome.json   — RAST annotated genome (intermediate)
  genome.gff    — GFF3 feature annotations
  genome.faa    — Predicted protein sequences
  genome.gbk    — GenBank format annotation

HELP_EOF
    exit 0
fi

exec rast-process-genome "$@"
