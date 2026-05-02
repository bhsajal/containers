#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# TCDB container entrypoint — pipeline-standard interface
# Installed at /usr/local/bin/run inside the container.
#
# Interface:
#   run -i /input/org.faa -o /output -d /db [-t THREADS]
#
# Runs DIAMOND blastp against TCDB and writes 7-column tabular output.
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

usage() {
    cat <<'HELP_EOF'

TCDB — Transporter Classification Database search via DIAMOND blastp

USAGE
  docker run ... annotation/tcdb:latest \
    -i /input/organism.faa -o /output -d /db [-t THREADS]

REQUIRED MOUNTS
  /input/organism.faa   Protein FASTA (.faa) — read-only
  /output/              Output directory — writable
  /db/                  TCDB database dir containing tcdb.dmnd + families.tsv

REQUIRED OPTIONS
  -i FILE     Protein FASTA input file (inside container)
  -o DIR      Output directory         (inside container: /output)
  -d DIR      TCDB database directory  (inside container: /db)

OPTIONAL OPTIONS
  -t INT      CPU threads  [default: 1]
  --help      Show this help and exit

OUTPUTS  (written to /output)
  tcdb.tsv   — 7-col DIAMOND tabular: qseqid sseqid pident length evalue bitscore stitle

FILTERS
  E-value ≤ 1e-5, percent identity ≥ 30%, max 1 hit per query

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
    echo "[tcdb] ERROR: -i INPUT, -o OUTPUT, and -d DBDIR are required" >&2
    usage; exit 1
fi

DB="$DBDIR/tcdb"
if [[ ! -f "${DB}.dmnd" ]]; then
    echo "[tcdb] ERROR: DIAMOND database not found: ${DB}.dmnd" >&2
    exit 1
fi

mkdir -p "$OUTPUT"

# Skip if already complete
if [[ -s "$OUTPUT/tcdb.tsv" ]]; then
    echo "[tcdb] Complete output already exists, skipping (delete manually to re-run)"
    exit 0
fi

echo "[tcdb] Running DIAMOND blastp with $THREADS threads (evalue 1e-5, id 30%, max-target-seqs 1)..."
diamond blastp \
    -q "$INPUT" \
    -d "$DB" \
    -o "$OUTPUT/tcdb.tsv" \
    -f 6 qseqid sseqid pident length evalue bitscore stitle \
    -p "$THREADS" \
    -e 1e-5 \
    --id 30 \
    -k 1 \
    --quiet

echo "[tcdb] DIAMOND blastp complete."
