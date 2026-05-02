#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: run -i <input.faa> -o <output_dir> -d <db_dir> [-t <threads>]"
}

INPUT=""; OUTPUT=""; DBDIR=""; THREADS=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i) INPUT="$2";   shift 2 ;;
        -o) OUTPUT="$2";  shift 2 ;;
        -d) DBDIR="$2";   shift 2 ;;
        -t) THREADS="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

[[ -z "$INPUT"  ]] && { echo "[eggnog] ERROR: -i required" >&2; exit 1; }
[[ -z "$OUTPUT" ]] && { echo "[eggnog] ERROR: -o required" >&2; exit 1; }
[[ -z "$DBDIR"  ]] && { echo "[eggnog] ERROR: -d required" >&2; exit 1; }
[[ ! -f "$INPUT" ]] && { echo "[eggnog] ERROR: input not found: $INPUT" >&2; exit 1; }

# Require eggnog.db
[[ ! -f "$DBDIR/eggnog.db" ]] && { echo "[eggnog] ERROR: eggnog.db not found in $DBDIR" >&2; exit 1; }

mkdir -p "$OUTPUT"

# Remove partial output from a previous run, but only if annotations file is absent/incomplete
ANNOTATIONS="$OUTPUT/eggnog_out.emapper.annotations"
if [[ ! -f "$ANNOTATIONS" ]] || ! grep -q "^[^#]" "$ANNOTATIONS" 2>/dev/null; then
    rm -f "$OUTPUT/eggnog_out.emapper.hits" \
           "$OUTPUT/eggnog_out.emapper.seed_orthologs" \
           "$OUTPUT/eggnog_out.emapper.annotations" 2>/dev/null || true
else
    echo "[eggnog] Complete output already exists, skipping (delete manually to re-run)"
    exit 0
fi

# Use diamond mode (faster, no per-taxon HMM needed; eggnog_proteins.dmnd required)
# Fall back to hmmer mode if diamond DB is absent but Bacteria.hmm is present
if [[ -f "$DBDIR/eggnog_proteins.dmnd" ]]; then
    MODE="-m diamond"
    echo "[eggnog] Running emapper in diamond mode (threads=$THREADS)..."
elif [[ -f "$DBDIR/Bacteria.hmm" ]]; then
    MODE="-m hmmer -d Bacteria"
    echo "[eggnog] Running emapper in hmmer/Bacteria mode (threads=$THREADS)..."
else
    echo "[eggnog] ERROR: neither eggnog_proteins.dmnd nor Bacteria.hmm found in $DBDIR" >&2
    exit 1
fi

exec emapper.py \
    $MODE \
    --data_dir "$DBDIR" \
    -i "$INPUT" \
    -o eggnog_out \
    --output_dir "$OUTPUT" \
    --cpu "$THREADS" \
    --dmnd_db "$DBDIR/eggnog_proteins.dmnd" \
    --block_size 2.0 \
    --index_chunks 1

