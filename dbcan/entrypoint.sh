#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# CONTAINER ENTRYPOINT — dbCAN (run_dbcan v5)
# Standard pipeline interface: -i INPUT -o OUTPUT -d DBDIR [-t THREADS]
#
# Runs:
#   run_dbcan CAZyme_annotation --mode protein --input_raw_data INPUT
#       --db_dir DBDIR --output_dir OUTPUT/native --threads THREADS
#       --methods diamond,hmm[,dbCANsub]
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

INPUT=""
OUTPUT=""
DBDIR=""
THREADS=1

usage() {
    echo "Usage: run -i <input.faa> -o <output_dir> -d <db_dir> [-t <threads>]"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i) INPUT="$2";   shift 2 ;;
        -o) OUTPUT="$2";  shift 2 ;;
        -d) DBDIR="$2";   shift 2 ;;
        -t) THREADS="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

[[ -z "$INPUT"  ]] && { echo "[dbcan] ERROR: -i INPUT required" >&2; usage; }
[[ -z "$OUTPUT" ]] && { echo "[dbcan] ERROR: -o OUTPUT required" >&2; usage; }
[[ -z "$DBDIR"  ]] && { echo "[dbcan] ERROR: -d DBDIR required" >&2;  usage; }
[[ ! -f "$INPUT" ]] && { echo "[dbcan] ERROR: Input file not found: $INPUT" >&2; exit 1; }
[[ ! -f "$DBDIR/CAZy.dmnd" ]] && { echo "[dbcan] ERROR: CAZy.dmnd not found in $DBDIR" >&2; exit 1; }
[[ ! -f "$DBDIR/dbCAN.hmm"  ]] && { echo "[dbcan] ERROR: dbCAN.hmm not found in $DBDIR" >&2; exit 1; }

mkdir -p "$OUTPUT"

# Skip if already complete
if [[ -s "$OUTPUT/overview.tsv" ]]; then
    echo "[dbcan] Complete output already exists, skipping (delete manually to re-run)"
    exit 0
fi

# run_dbcan looks for dbCAN-sub.hmm (dash); create alias if only underscore version exists
if [[ -f "$DBDIR/dbCAN_sub.hmm" && ! -f "$DBDIR/dbCAN-sub.hmm" ]]; then
    cp "$DBDIR/dbCAN_sub.hmm" "$DBDIR/dbCAN-sub.hmm" 2>/dev/null || true
fi

# Enable sub-family HMM method if the database file is present and non-empty
METHODS="diamond,hmm"
if [[ -s "$DBDIR/dbCAN-sub.hmm" || -s "$DBDIR/dbCAN_sub.hmm" ]]; then
    echo "[dbcan] Sub-family HMM found: enabling dbCANsub"
    METHODS="diamond,hmm,dbCANsub"
fi

echo "[dbcan] Running run_dbcan with methods: $METHODS (threads=$THREADS)..."
run_dbcan CAZyme_annotation \
    --mode protein \
    --input_raw_data "$INPUT" \
    --db_dir         "$DBDIR" \
    --output_dir     "$OUTPUT" \
    --threads        "$THREADS" \
    --methods        "$METHODS"

echo "[dbcan] run_dbcan complete."
