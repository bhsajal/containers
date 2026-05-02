#!/usr/bin/env bash
# entrypoint.sh — fastANI runner
# Mounts: /input = genome root dir, /output = ani output dir
#
# Modes:
#   all-vs-all (default):  --ql and --rl both set to all genomes in /input
#   targeted (recommended for large sets): provide /queries/query_list.txt
#     listing specific .fna paths to use as queries; all /input genomes used
#     as references. Avoids OOM on large reference sets.

set -euo pipefail

THREADS=8
TOP_N=5

while [[ $# -gt 0 ]]; do
    case "$1" in
        --threads) THREADS="$2"; shift 2 ;;
        --top-n)   TOP_N="$2";   shift 2 ;;
        *) echo "[ani] Unknown arg: $1" >&2; exit 1 ;;
    esac
done

# ── Build reference list (all genomes in /input) ──────────────────────────────
echo "[ani] Collecting genome FASTA files from /input ..."
NATIVE_DIR="/output/native"
mkdir -p "$NATIVE_DIR"
REF_LIST="$NATIVE_DIR/ref_list.txt"
> "$REF_LIST"

for org_dir in /input/*/; do
    org=$(basename "$org_dir")
    fna=$(ls "$org_dir/gene_calls/${org}.fna" 2>/dev/null || true)
    if [[ -z "$fna" ]]; then
        fna=$(ls "$org_dir/gene_calls/"*.fna 2>/dev/null | head -1 || true)
    fi
    if [[ -n "$fna" && -s "$fna" ]]; then
        echo "$fna" >> "$REF_LIST"
    else
        echo "[ani] WARNING: no .fna found for $org, skipping" >&2
    fi
done

N_REF=$(wc -l < "$REF_LIST")
echo "[ani] Reference genomes: $N_REF"

# ── Determine query list ──────────────────────────────────────────────────────
QUERY_LIST="$NATIVE_DIR/query_paths.txt"
if [[ -f "/queries/query_list.txt" ]]; then
    # Targeted mode: lines are full /input paths written by the batch script.
    cp "/queries/query_list.txt" "$QUERY_LIST"
    N_QUERY=$(wc -l < "$QUERY_LIST")
    echo "[ani] Targeted mode: $N_QUERY query genomes × $N_REF reference genomes"
else
    # All-vs-all mode
    cp "$REF_LIST" "$QUERY_LIST"
    N_QUERY=$N_REF
    echo "[ani] All-vs-all mode: $N_QUERY × $N_REF"
fi

if [[ "$N_QUERY" -lt 1 || "$N_REF" -lt 2 ]]; then
    echo "[ani] ERROR: need at least 1 query and 2 reference genomes" >&2
    exit 1
fi

# ── Run fastANI in reference chunks to stay within memory limits ──────────────
CHUNK_SIZE=500
RAW_OUT="$NATIVE_DIR/ani_results.tsv"
> "$RAW_OUT"

CHUNK_DIR=$(mktemp -d)
split -l "$CHUNK_SIZE" "$REF_LIST" "$CHUNK_DIR/chunk_"
CHUNKS=("$CHUNK_DIR"/chunk_*)
N_CHUNKS=${#CHUNKS[@]}
echo "[ani] Running fastANI in $N_CHUNKS chunk(s) of ≤$CHUNK_SIZE refs (threads=$THREADS) ..."

CHUNK_NUM=0
for CHUNK_FILE in "${CHUNKS[@]}"; do
    CHUNK_NUM=$((CHUNK_NUM + 1))
    CHUNK_OUT="$CHUNK_DIR/ani_chunk_${CHUNK_NUM}.tsv"
    echo "[ani]   Chunk $CHUNK_NUM/$N_CHUNKS ..."
    fastANI \
        --ql "$QUERY_LIST" \
        --rl "$CHUNK_FILE" \
        --threads "$THREADS" \
        -o "$CHUNK_OUT" \
        2>&1 | grep -v "^#" || true
    if [[ -f "$CHUNK_OUT" ]]; then
        cat "$CHUNK_OUT" >> "$RAW_OUT"
    fi
done
rm -rf "$CHUNK_DIR"

echo "[ani] fastANI done. Raw output: $RAW_OUT ($(wc -l < "$RAW_OUT") hits)"

# Post-process: compute closest organisms table
echo "[ani] Building closest_organisms.tsv (top $TOP_N per genome) ..."
python3 /container/scripts/process_ani.py \
    --input  "$RAW_OUT" \
    --output "/output/closest_organisms.tsv" \
    --top-n  "$TOP_N"
echo "[ani] Native output  : $RAW_OUT"
echo "[ani] Processed output: /output/closest_organisms.tsv"

# ── Write pipeline.txt provenance record ─────────────────────────────────────
FASTANI_VERSION=$(fastANI --version 2>&1 | head -1 || echo "unknown")
PIPELINE_FILE="/output/pipeline.txt"
cat > "$PIPELINE_FILE" << EOF
================================================================================
ANI ANALYSIS PIPELINE - PROVENANCE RECORD
================================================================================
Date: $(date '+%Y-%m-%d %H:%M:%S %Z')
Tool: fastANI
Version: ${FASTANI_VERSION}

================================================================================
PARAMETERS
================================================================================
Threads:      ${THREADS}
Top-N:        ${TOP_N}
Chunk size:   ${CHUNK_SIZE} references per fastANI call
Mode:         $(if [[ -f "/queries/query_list.txt" ]]; then echo "targeted"; else echo "all-vs-all"; fi)
Queries:      ${N_QUERY} genomes
References:   ${N_REF} genomes

================================================================================
STEP 1: COLLECT GENOME FASTA FILES
================================================================================
Input directory:  /input  (RASTtk output root)
File pattern:     /input/<organism>/gene_calls/<organism>.fna
Reference list:   ${REF_LIST}
Query list:       ${QUERY_LIST}

================================================================================
STEP 2: RUN fastANI (all-vs-all)
================================================================================
Script: processing/containers/ani/scripts/entrypoint.sh

fastANI was run as a series of batches rather than one single call. With
${N_REF} genomes, loading all references at once would exhaust memory.
The reference list was split into batches of ${CHUNK_SIZE} genomes each
using the Unix \`split\` command, fastANI was called once per batch, and
all batch outputs were concatenated into the single ani_results.tsv file.

Batching code (from entrypoint.sh):
  CHUNK_SIZE=${CHUNK_SIZE}
  split -l "\$CHUNK_SIZE" "\$REF_LIST" "\$CHUNK_DIR/chunk_"
  for CHUNK_FILE in "\${CHUNKS[@]}"; do
      fastANI \\
          --ql "\$QUERY_LIST" \\
          --rl "\$CHUNK_FILE" \\
          --threads "\$THREADS" \\
          -o "\$CHUNK_OUT"
      cat "\$CHUNK_OUT" >> "\$RAW_OUT"   # accumulate into final output
  done

Batches run: ${N_CHUNKS} (${N_REF} genomes ÷ ${CHUNK_SIZE} per batch)
Raw hits output: ${RAW_OUT}
Total hits: $(wc -l < "$RAW_OUT")

Note: fastANI only reports pairs with ANI >= 75% (default minimum threshold).
      Organisms with no hits above this threshold have no entry in the results.

================================================================================
STEP 3: POST-PROCESS → closest_organisms.tsv
================================================================================
Command:
  python3 /container/scripts/process_ani.py \\
      --input  ${RAW_OUT} \\
      --output /output/closest_organisms.tsv \\
      --top-n  ${TOP_N}

================================================================================
OUTPUT FILES
================================================================================
  native/ref_list.txt              Reference genome paths
  native/query_paths.txt           Query genome paths
  native/ani_results.tsv           Raw fastANI pairwise hits
  closest_organisms.tsv            Top-${TOP_N} closest organisms per genome
================================================================================
EOF

echo "[ani] Provenance record: $PIPELINE_FILE"
echo "[ani] Done."
