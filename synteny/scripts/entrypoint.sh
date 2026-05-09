#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# CONTAINER ENTRYPOINT — Synteny (clinker gene cluster comparison)
# Placed at /container/scripts/entrypoint.sh inside the container.
# Invoked by: apptainer run synteny.sif [OPTIONS]
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
RASTTK_DIR="/input"
OUTPUT_DIR="/output"
ORGANISM=""
PARTNERS=""
IDENTITY="0.3"   # clinker -i threshold (fraction, 0–1)
JOBS="0"         # clinker -j parallel alignments (0 = all CPUs)

# ── Help ──────────────────────────────────────────────────────────────────────
usage() {
    cat <<'HELP_EOF'

Synteny Analysis Container — clinker gene cluster comparison
─────────────────────────────────────────────────────────────

USAGE
  apptainer run --bind <rasttk_root>:/input:ro,<out_dir>:/output:rw \
    synteny.sif --organism <name> --partners <A,B,C,D,E> [OPTIONS]

REQUIRED MOUNTS
  /input    RASTtk output root. Expected layout per organism:
              /input/<organism>/gene_calls/<organism>.gbk
  /output   Per-organism output directory (output/synteny/<organism>).

REQUIRED OPTIONS
  --organism NAME         Query organism name

OPTIONAL OPTIONS
  --partners A,B,C,D,E   Comma-separated partner organism names (top-5 closest)
  --identity FLOAT        Minimum alignment identity (default: 0.3)
  --jobs N                Parallel alignment jobs; 0 = all CPUs (default: 0)
  --help                  Show this message

OUTPUT (written to /output/native/)
  plot.html               Interactive clinker visualisation
  alignments.csv          Gene-gene pairwise identity table (clinker -o)
  matrix.tsv              Cluster-vs-cluster similarity matrix (clinker -mo)
  session.json            clinker session for replaying the plot (clinker -s)
  synteny_links.tsv       Structured post-processed gene link table
  pipeline.txt            Provenance record

HELP_EOF
}

if [[ $# -eq 0 || "$1" == "--help" || "$1" == "-h" ]]; then
    usage; exit 0
fi

# ── Argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --organism)   ORGANISM="$2";   shift 2 ;;
        --partners)   PARTNERS="$2";   shift 2 ;;
        --identity)   IDENTITY="$2";   shift 2 ;;
        --jobs)       JOBS="$2";       shift 2 ;;
        --help|-h)    usage; exit 0 ;;
        *) echo "[synteny] ERROR: Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

[[ -z "$ORGANISM" ]] && { echo "[synteny] ERROR: --organism is required" >&2; exit 1; }

# ── Validate inputs ────────────────────────────────────────────────────────────
QUERY_GBK="$RASTTK_DIR/$ORGANISM/gene_calls/$ORGANISM.gbk"
[[ ! -f "$QUERY_GBK" ]] && {
    echo "[synteny] ERROR: GenBank file not found: $QUERY_GBK" >&2; exit 1
}

NATIVE_DIR="$OUTPUT_DIR/native"
mkdir -p "$NATIVE_DIR"

# ── Assemble list of GBK files ─────────────────────────────────────────────────
GBK_FILES=("$QUERY_GBK")

if [[ -n "$PARTNERS" ]]; then
    IFS=',' read -ra PARTNER_LIST <<< "$PARTNERS"
    for partner in "${PARTNER_LIST[@]}"; do
        partner="$(echo "$partner" | tr -d '[:space:]')"
        gbk="$RASTTK_DIR/$partner/gene_calls/$partner.gbk"
        if [[ -f "$gbk" ]]; then
            GBK_FILES+=("$gbk")
        else
            echo "[synteny] WARNING: GBK not found for partner '$partner', skipping: $gbk" >&2
        fi
    done
fi

echo "[synteny] Query   : $ORGANISM"
echo "[synteny] Partners: $PARTNERS"
echo "[synteny] GBK files (${#GBK_FILES[@]}):"
for f in "${GBK_FILES[@]}"; do echo "  $f"; done
echo "[synteny] identity>=${IDENTITY}  jobs=${JOBS}"

# ── Run clinker ────────────────────────────────────────────────────────────────
ALIGN_CSV="$NATIVE_DIR/alignments.csv"
MATRIX_TSV="$NATIVE_DIR/matrix.tsv"
SESSION_JSON="$NATIVE_DIR/session.json"
PLOT_HTML="$NATIVE_DIR/plot.html"

echo "[synteny] Running clinker ..."
clinker "${GBK_FILES[@]}" \
    -i  "$IDENTITY" \
    -j  "$JOBS" \
    -o  "$ALIGN_CSV"  -dl "," -dc 4 \
    -mo "$MATRIX_TSV" \
    -s  "$SESSION_JSON"

echo "[synteny] clinker done."
echo "[synteny]   alignments : $ALIGN_CSV"
echo "[synteny]   matrix     : $MATRIX_TSV"
echo "[synteny]   session    : $SESSION_JSON"

# ── Post-process: alignments.csv → synteny_links.tsv ──────────────────────────
LINKS_TSV="$NATIVE_DIR/synteny_links.tsv"
echo "[synteny] Post-processing alignments -> $LINKS_TSV ..."
python3 /container/scripts/process_clinker.py \
    --alignments "$ALIGN_CSV" \
    --organism   "$ORGANISM" \
    --out        "$LINKS_TSV"

echo "[synteny] synteny_links.tsv rows: $(tail -n +2 "$LINKS_TSV" | wc -l)"

# ── Provenance ────────────────────────────────────────────────────────────────
CLINKER_VER=$(clinker --version 2>&1 | head -1 || echo "unknown")
N_LINKS=$(tail -n +2 "$LINKS_TSV" 2>/dev/null | wc -l || echo 0)

cat > "$NATIVE_DIR/pipeline.txt" <<EOF
================================================================================
SYNTENY ANALYSIS — PROVENANCE RECORD
================================================================================
organism    : $ORGANISM
partners    : $PARTNERS
date        : $(date -u '+%Y-%m-%dT%H:%M:%SZ')
tool        : clinker $CLINKER_VER
identity    : $IDENTITY
jobs        : $JOBS
n_gbk_files : ${#GBK_FILES[@]}
n_links     : $N_LINKS

Output files:
  native/alignments.csv     — raw gene-gene identity table (clinker -o)
  native/matrix.tsv         — cluster similarity matrix (clinker -mo)
  native/session.json       — clinker session JSON (clinker -s)
  native/synteny_links.tsv  — structured gene link table (post-processed)
================================================================================
EOF

echo "[synteny] Done: $ORGANISM  ->  $OUTPUT_DIR/"
