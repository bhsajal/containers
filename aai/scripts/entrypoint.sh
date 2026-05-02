#!/usr/bin/env bash
# entrypoint.sh — CompareM AAI all-vs-all
# Usage: entrypoint.sh [--threads N] [--top-n N]
set -euo pipefail

THREADS=8
TOP_N=5

while [[ $# -gt 0 ]]; do
    case "$1" in
        --threads) THREADS="$2"; shift 2 ;;
        --top-n)   TOP_N="$2";   shift 2 ;;
        *) echo "[aai] Unknown argument: $1" >&2; exit 1 ;;
    esac
done

INPUT_DIR="/input"
OUTPUT_DIR="/output"
NATIVE_DIR="/output/native"
FAA_POOL="/tmp/faa_pool"
COMPAREM_OUT="/tmp/comparem_out"
RAW_OUT="$NATIVE_DIR/aai_results.tsv"
CLOSEST_OUT="$OUTPUT_DIR/closest_organisms.tsv"

# ── Step 1: Collect .faa files into a flat pool directory ────────────────────
# CompareM aai_wf takes a directory of protein FASTA files.
# We symlink each organism's .faa into /tmp/faa_pool/<organism>.faa
echo "[aai] Collecting protein FASTA files from $INPUT_DIR ..."
mkdir -p "$FAA_POOL"
COUNT=0
for org_dir in "$INPUT_DIR"/*/; do
    org=$(basename "$org_dir")
    faa_file="$org_dir/gene_calls/$org.faa"
    if [[ -f "$faa_file" ]]; then
        ln -sf "$faa_file" "$FAA_POOL/$org.faa"
        COUNT=$((COUNT + 1))
    else
        echo "[aai] WARNING: no .faa found for $org, skipping"
    fi
done
echo "[aai] Found $COUNT protein FASTAs for all-vs-all AAI comparison"

if [[ $COUNT -lt 2 ]]; then
    echo "[aai] ERROR: need at least 2 genomes for AAI" >&2
    exit 1
fi

# ── Step 2: Run CompareM aai_wf ──────────────────────────────────────────────
echo "[aai] Running CompareM aai_wf ($COUNT × $COUNT) with $THREADS threads ..."
mkdir -p "$COMPAREM_OUT"
comparem aai_wf \
    --file_ext faa \
    --proteins \
    --cpus "$THREADS" \
    "$FAA_POOL" \
    "$COMPAREM_OUT"

echo "[aai] CompareM done."

# ── Step 3: Extract pairwise AAI table ───────────────────────────────────────
# CompareM writes: $COMPAREM_OUT/aai/aai_summary.tsv
# Columns (tab-separated, header starts with #):
#   #Genome A | Genes in A | Genome B | Genes in B | # orthologous genes | Mean AAI | Std AAI | OF
SUMMARY="$COMPAREM_OUT/aai/aai_summary.tsv"
if [[ ! -f "$SUMMARY" ]]; then
    echo "[aai] ERROR: CompareM summary not found at $SUMMARY" >&2
    ls "$COMPAREM_OUT"/aai/ >&2 2>/dev/null || true
    exit 1
fi

# Copy raw summary to native/ subdir
mkdir -p "$NATIVE_DIR"
cp "$SUMMARY" "$RAW_OUT"
echo "[aai] Native output  : $RAW_OUT"

# ── Step 4: Build closest_organisms.tsv ─────────────────────────────────────
echo "[aai] Building closest_organisms.tsv (top $TOP_N per genome) ..."
python3 /container/scripts/process_aai.py \
    --input  "$RAW_OUT" \
    --output "$CLOSEST_OUT" \
    --top-n  "$TOP_N"
echo "[aai] Processed output: $CLOSEST_OUT"

# ── Write pipeline.txt provenance record ─────────────────────────────────────
COMPAREM_VERSION=$(comparem --version 2>&1 | head -1 || echo "unknown")
DIAMOND_VERSION=$(diamond version 2>&1 | head -1 || echo "unknown")
PIPELINE_FILE="$OUTPUT_DIR/pipeline.txt"
N_ROWS=$(tail -n +2 "$CLOSEST_OUT" | wc -l)
cat > "$PIPELINE_FILE" << EOF
================================================================================
AAI ANALYSIS PIPELINE - PROVENANCE RECORD
================================================================================
Date: $(date '+%Y-%m-%d %H:%M:%S %Z')
Tool: CompareM (DIAMOND-based AAI)
Version: ${COMPAREM_VERSION}
DIAMOND version: ${DIAMOND_VERSION}

================================================================================
PARAMETERS
================================================================================
Threads:  ${THREADS}
Top-N:    ${TOP_N}
Mode:     all-vs-all
Genomes:  ${COUNT}

================================================================================
STEP 1: COLLECT PROTEIN FASTA FILES
================================================================================
Input directory:  ${INPUT_DIR}  (RASTtk output root)
File pattern:     /input/<organism>/gene_calls/<organism>.faa
FAA pool dir:     ${FAA_POOL}   (symlinked for CompareM)
Genomes found:    ${COUNT}

================================================================================
STEP 2: RUN CompareM aai_wf
================================================================================
Command:
  comparem aai_wf \\
      --file_ext faa \\
      --proteins \\
      --cpus ${THREADS} \\
      ${FAA_POOL} \\
      ${COMPAREM_OUT}

Raw summary: ${SUMMARY}

================================================================================
STEP 3: POST-PROCESS → closest_organisms.tsv
================================================================================
Command:
  python3 /container/scripts/process_aai.py \\
      --input  ${RAW_OUT} \\
      --output ${CLOSEST_OUT} \\
      --top-n  ${TOP_N}

Output rows: ${N_ROWS}

================================================================================
OUTPUT FILES
================================================================================
  native/aai_results.tsv      Raw CompareM aai_summary.tsv
  closest_organisms.tsv       Top-${TOP_N} closest organisms per genome
================================================================================
EOF

echo "[aai] Provenance record: $PIPELINE_FILE"
echo "[aai] Done."
