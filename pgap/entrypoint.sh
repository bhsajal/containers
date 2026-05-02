#!/usr/bin/env bash
# PGAP container entrypoint — standard -i/-o/-d/-t interface
# Runs HMMER hmmscan against NCBI PGAP HMM library (hmm_PGAP.LIB)
# The PGAP HMM library contains NCBIfam + TIGRfam models.
#
# Usage: run -i <proteins.faa> -o <output_dir> -d <db_dir> [-t <threads>]
set -euo pipefail

usage() {
    echo "Usage: run -i <proteins.faa> -o <output_dir> -d <db_dir> [-t <threads>]"
}

INPUT=""; OUTPUT=""; DBDIR=""; THREADS=4

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

[[ -z "$INPUT"  ]] && { echo "[pgap] ERROR: -i required" >&2; exit 1; }
[[ -z "$OUTPUT" ]] && { echo "[pgap] ERROR: -o required" >&2; exit 1; }
[[ -z "$DBDIR"  ]] && { echo "[pgap] ERROR: -d required" >&2; exit 1; }
[[ ! -f "$INPUT" ]] && { echo "[pgap] ERROR: input not found: $INPUT" >&2; exit 1; }

HMM_LIB="$DBDIR/hmm_PGAP.LIB"
[[ ! -f "$HMM_LIB" ]] && { echo "[pgap] ERROR: hmm_PGAP.LIB not found in $DBDIR" >&2; exit 1; }

mkdir -p "$OUTPUT"

# Skip if already complete
if [[ -s "$OUTPUT/pgap.domtblout" ]]; then
    echo "[pgap] Complete output already exists, skipping (delete to re-run)"
    exit 0
fi

ORGANISM="$(basename "$INPUT" .faa)"

echo "[pgap] Input:    $INPUT ($ORGANISM)"
echo "[pgap] Database: $HMM_LIB"
echo "[pgap] Threads:  $THREADS"
echo "[pgap] Output:   $OUTPUT"

# Press the HMM database if needed
if [[ ! -f "${HMM_LIB}.h3i" ]]; then
    echo "[pgap] HMM database not pressed — running hmmpress..."
    hmmpress -f "$HMM_LIB"
fi

echo "[pgap] Running hmmscan --cut_tc ..."
hmmscan \
    --cpu "$THREADS" \
    --cut_tc \
    --domtblout "$OUTPUT/pgap.domtblout" \
    --noali \
    -o "$OUTPUT/pgap.out" \
    "$HMM_LIB" \
    "$INPUT"

echo "[pgap] Done. domtblout: $OUTPUT/pgap.domtblout"
