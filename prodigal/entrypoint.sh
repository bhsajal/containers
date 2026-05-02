#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# Prodigal container entrypoint
# Installed at /usr/local/bin/run inside the container.
#
# No arguments or --help/-h  →  print usage and exit 0
# Any other arguments        →  exec prodigal "$@"
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [[ $# -eq 0 || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'HELP_EOF'

Prodigal v2.6.3 — Prokaryotic gene prediction

USAGE
  prodigal -i <input.fna> [OPTIONS]

KEY OPTIONS
  -i FILE    Input genomic sequence (FASTA)
  -a FILE    Write protein translations to FILE  (.faa)
  -d FILE    Write nucleotide CDS sequences to FILE
  -f FORMAT  Output format: gbk | gff | sqn | sco  [default: gbk]
  -o FILE    Output main annotation file
  -p MODE    Procedure: single | meta  [default: single]
  -q         Quiet mode (suppress progress messages)

MOUNT POINTS (bind at runtime)
  /input/    Genome FASTA directory or file
  /output/   Protein .faa and GFF outputs

EXAMPLE
  apptainer run --bind <input>:/input,<output>:/output prodigal.sif \
    prodigal \
      -i  /input/genome.fna \
      -a  /output/genome.faa \
      -f  gff \
      -o  /output/genome.gff \
      -q

OUTPUTS
  genome.faa   — predicted protein sequences
  genome.gff   — GFF3 gene predictions

HELP_EOF
    exit 0
fi

exec prodigal "$@"
