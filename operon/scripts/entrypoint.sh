#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# Operon container entrypoint — pipeline-standard interface
# Installed at /container/scripts/entrypoint.sh inside the container.
#
# Steps performed inside the container:
#   1. Convert RAST GFF3 + FAA → Prodigal-style FAA  (convert_rast_to_uniop.py)
#   2. Run UniOP  -a <converted.faa> -t <output_dir> --operon_flag True
#      → writes uniop.pred and uniop.operon into OUTPUT
#   3. Write the converted FAA to OUTPUT as well (process.py needs it for
#      gene-ID mapping)
#
# Skip logic: if OUTPUT/uniop.operon already exists, exit 0 immediately.
#
# Interface:
#   entrypoint.sh -i /input/org.faa -g /input/org.gff -o /output [-t THREADS]
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

usage() {
    cat <<'HELP_EOF'

Operon Prediction — UniOP (intergenic-distance probabilistic model)

USAGE
  docker run ... annotation/operon:latest \
    -i /input/organism.faa  \
    -g /input/organism.gff  \
    -o /output              \
    [-t THREADS]

REQUIRED MOUNTS
  /input/organism.faa   RAST protein FASTA
  /input/organism.gff   RAST GFF3 annotation
  /output/              Output directory — writable

NOTE
  Writes to /output:
    uniop_input.faa   Prodigal-style FAA converted from RAST input
    uniop.pred        Pairwise operon prediction scores
    uniop.operon      Operon cluster assignments (gene indices)

HELP_EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────
FAA="" GFF="" OUTPUT="" THREADS=4

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i) FAA="$2";     shift 2 ;;
        -g) GFF="$2";     shift 2 ;;
        -o) OUTPUT="$2";  shift 2 ;;
        -t) THREADS="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "[operon] Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -z "$FAA" || -z "$GFF" || -z "$OUTPUT" ]]; then
    echo "[operon] ERROR: -i FAA, -g GFF, and -o OUTPUT are all required" >&2
    usage; exit 1
fi
[[ ! -f "$FAA" ]] && { echo "[operon] ERROR: FAA not found: $FAA" >&2; exit 1; }
[[ ! -f "$GFF" ]] && { echo "[operon] ERROR: GFF not found: $GFF" >&2; exit 1; }

mkdir -p "$OUTPUT"

# ── Skip if already done ──────────────────────────────────────────────────────
if [[ -f "$OUTPUT/uniop.operon" ]]; then
    echo "[operon] Output already exists — skipping. Delete $OUTPUT/uniop.operon to rerun."
    exit 0
fi

CONVERTED_FAA="$OUTPUT/uniop_input.faa"

# ── Step 1: Convert RAST → Prodigal-style FAA ────────────────────────────────
echo "[operon] Converting RAST GFF3 + FAA → Prodigal-style FAA ..."
python3 /container/scripts/convert_rast_to_uniop.py "$GFF" "$FAA" "$CONVERTED_FAA"

GENE_COUNT=$(grep -c '^>' "$CONVERTED_FAA" 2>/dev/null || echo 0)
echo "[operon] Converted $GENE_COUNT genes → $CONVERTED_FAA"

# ── Step 2: Run UniOP ─────────────────────────────────────────────────────────
echo "[operon] Running UniOP ..."
python3 "$UNIOP_HOME/src/UniOP" \
    -a "$CONVERTED_FAA" \
    -t "$OUTPUT" \
    --operon_flag True

# ── Verify outputs ────────────────────────────────────────────────────────────
for expected in uniop.pred uniop.operon; do
    if [[ ! -f "$OUTPUT/$expected" ]]; then
        echo "[operon] ERROR: expected output not found: $OUTPUT/$expected" >&2
        exit 1
    fi
done

echo "[operon] Done. Outputs:"
echo "  $OUTPUT/uniop_input.faa"
echo "  $OUTPUT/uniop.pred"
echo "  $OUTPUT/uniop.operon"
