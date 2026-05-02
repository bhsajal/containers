#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MEROPS container entrypoint — pipeline-standard interface
# Installed at /usr/local/bin/run inside the container.
#
# Interface:
#   run -i /input/org.faa -o /output -d /db [-t THREADS]
#
# Runs DIAMOND blastp against MEROPS pepunit database and writes
# 13-column tabular output (12 standard + stitle).
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

usage() {
    cat <<'HELP_EOF'

MEROPS — Peptidase identification via DIAMOND blastp

USAGE
  docker run ... annotation/merops:latest \
    -i /input/organism.faa -o /output -d /db [-t THREADS]

REQUIRED MOUNTS
  /input/organism.faa   Protein FASTA (.faa) — read-only
  /output/              Output directory — writable
  /db/                  MEROPS database dir containing merops.dmnd

REQUIRED OPTIONS
  -i FILE     Protein FASTA input file (inside container)
  -o DIR      Output directory         (inside container: /output)
  -d DIR      MEROPS database directory (inside container: /db)

OPTIONAL OPTIONS
  -t INT      CPU threads  [default: 1]
  --help      Show this help and exit

OUTPUTS  (written to /output)
  merops.tsv  — 13-col DIAMOND tabular:
                qseqid sseqid pident length mismatch gapopen
                qstart qend sstart send evalue bitscore stitle

FILTERS
  E-value ≤ 1e-5, max 1 hit per query

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
    echo "[merops] ERROR: -i INPUT, -o OUTPUT, and -d DBDIR are required" >&2
    usage; exit 1
fi

DB="$DBDIR/merops"
if [[ ! -f "${DB}.dmnd" ]]; then
    echo "[merops] ERROR: DIAMOND database not found: ${DB}.dmnd" >&2
    exit 1
fi

mkdir -p "$OUTPUT"

# Skip if already complete
if [[ -s "$OUTPUT/merops.tsv" ]]; then
    echo "[merops] Complete output already exists, skipping (delete manually to re-run)"
    exit 0
fi

echo "[merops] Running DIAMOND blastp with $THREADS threads (evalue 1e-5, max-target-seqs 1)..."
diamond blastp \
    -q "$INPUT" \
    -d "$DB" \
    -o "$OUTPUT/merops.tsv" \
    -f 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle \
    -p "$THREADS" \
    -e 1e-5 \
    -k 1 \
    --quiet

echo "[merops] DIAMOND blastp complete."
