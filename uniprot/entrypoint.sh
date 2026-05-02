#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# UniProt / Swiss-Prot container entrypoint — pipeline-standard interface
# Installed at /usr/local/bin/run inside the container.
#
# Interface:
#   run -i /input/org.faa -o /output -d /db [-t THREADS]
#
# Runs DIAMOND blastp against UniProt Swiss-Prot and writes 7-column tabular.
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

usage() {
    cat <<'HELP_EOF'

UniProt / Swiss-Prot — Protein homology search via DIAMOND blastp

USAGE
  docker run ... annotation/uniprot:latest \
    -i /input/organism.faa -o /output -d /db [-t THREADS]

REQUIRED MOUNTS
  /input/organism.faa   Protein FASTA (.faa) — read-only
  /output/              Output directory — writable
  /db/                  UniProt database dir containing uniprot_sprot.dmnd

REQUIRED OPTIONS
  -i FILE     Protein FASTA input file (inside container)
  -o DIR      Output directory         (inside container: /output)
  -d DIR      UniProt database directory (inside container: /db)

OPTIONAL OPTIONS
  -t INT      CPU threads  [default: 1]
  --help      Show this help and exit

OUTPUTS  (written to /output)
  uniprot.tsv   — 7-col DIAMOND tabular: qseqid sseqid pident length evalue bitscore stitle

FILTERS
  E-value ≤ 1e-5, percent identity ≥ 30%, max 1 hit per query (best hit only)

HELP_EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────
INPUT="" OUTPUT="" DBDIR="" THREADS=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i) INPUT="$2";   shift 2 ;;
        -o) OUTPUT="$2";  shift 2 ;;
        -d) DBDIR="$2";   shift 2 ;;
        -t) THREADS="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -z "$INPUT" || -z "$OUTPUT" || -z "$DBDIR" ]]; then
    echo "[uniprot] ERROR: -i INPUT, -o OUTPUT, and -d DBDIR are required" >&2
    usage; exit 1
fi

DB="$DBDIR/uniprot_sprot"
if [[ ! -f "${DB}.dmnd" ]]; then
    echo "[uniprot] ERROR: DIAMOND database not found: ${DB}.dmnd" >&2
    exit 1
fi

mkdir -p "$OUTPUT"

# Skip if already complete
if [[ -s "$OUTPUT/uniprot.tsv" ]]; then
    echo "[uniprot] Complete output already exists, skipping (delete manually to re-run)"
    exit 0
fi

echo "[uniprot] Running DIAMOND blastp with $THREADS threads (evalue 1e-5, id 30%, max-target-seqs 1)..."
diamond blastp \
    -q "$INPUT" \
    -d "$DB" \
    -o "$OUTPUT/uniprot.tsv" \
    -f 6 qseqid sseqid pident length evalue bitscore stitle \
    -p "$THREADS" \
    -e 1e-5 \
    --id 30 \
    -k 1

echo "[uniprot] DIAMOND blastp complete."
