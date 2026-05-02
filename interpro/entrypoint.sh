#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: run -i <input.faa> -o <output_dir> -d <db_dir> [-t <threads>] [-a <analyses>]"
    echo "  -a   Comma-separated analyses to run."
    echo "       Recommended (prokaryote-relevant): NCBIfam,PIRSF,HAMAP,Coils,CDD,SUPERFAMILY,Gene3D"
    echo "       Omit to run all available analyses (~15 databases, much slower)."
    echo "       Pfam/TIGRfam excluded by default (standalone stageC tools); PANTHER removed (eukaryote-focused)."
}

INPUT=""; OUTPUT=""; DBDIR=""; THREADS=1; ANALYSES=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i) INPUT="$2";    shift 2 ;;
        -o) OUTPUT="$2";   shift 2 ;;
        -d) DBDIR="$2";    shift 2 ;;
        -t) THREADS="$2";  shift 2 ;;
        -a) ANALYSES="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

[[ -z "$INPUT"  ]] && { echo "[interpro] ERROR: -i required" >&2; exit 1; }
[[ -z "$OUTPUT" ]] && { echo "[interpro] ERROR: -o required" >&2; exit 1; }
[[ -z "$DBDIR"  ]] && { echo "[interpro] ERROR: -d required" >&2; exit 1; }
[[ ! -f "$INPUT" ]] && { echo "[interpro] ERROR: input not found: $INPUT" >&2; exit 1; }

INTERPROSCAN=$(find "$DBDIR" -name "interproscan.sh" -maxdepth 3 ! -type l 2>/dev/null | head -1)
[[ -z "$INTERPROSCAN" || ! -x "$INTERPROSCAN" ]] && { echo "[interpro] ERROR: interproscan.sh not found/executable under $DBDIR" >&2; exit 1; }

mkdir -p "$OUTPUT"

# Skip if already complete (InterProScan writes an extensionless 'interpro' file, not 'interpro.tsv')
if [[ -s "$OUTPUT/interpro" ]]; then
    echo "[interpro] Native output already exists ($OUTPUT/interpro), skipping (delete manually to re-run)"
    exit 0
fi

# Strip stop codons (*) from FASTA — InterProScan rejects them
CLEAN_INPUT="$OUTPUT/input_clean.faa"
sed 's/\*//g' "$INPUT" > "$CLEAN_INPUT"

echo "[interpro] Running InterProScan (threads=$THREADS, analyses=${ANALYSES:-all})..."
APPS_FLAG=""
[[ -n "$ANALYSES" ]] && APPS_FLAG="--applications $ANALYSES"
exec "$INTERPROSCAN" \
    -i "$CLEAN_INPUT" \
    -o "$OUTPUT/interpro" \
    -f TSV \
    -cpu "$THREADS" \
    --goterms \
    --iprlookup \
    --pathways \
    --disable-precalc \
    $APPS_FLAG

