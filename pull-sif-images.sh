#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# pull-sif-images.sh — Pull all margie-annotation containers as Apptainer .sif
#
# Run this ONCE on an HPC cluster (or any Apptainer host) before using the
# annotation pipeline with --apptainer.
#
# Images are pulled from:  ghcr.io/sajalbhattarai/<tool>:latest
# SIF files are saved to:  <SIF_DIR>/<tool>.sif
#
# The pipeline reads SIF files from:
#   pipeline.conf → CONF_SIF_DIR   (default: <pipeline-root>/containers/sif)
#   or via --apptainer flag auto-detect
#
# Usage:
#   ./pull-sif-images.sh                        # pull all → ./sif/
#   ./pull-sif-images.sh /path/to/sif_dir       # pull all → custom dir
#   ./pull-sif-images.sh /path/to/sif_dir cog pfam  # pull specific tools only
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

REGISTRY="ghcr.io/sajalbhattarai"

# ── Arguments ─────────────────────────────────────────────────────────────────
SIF_DIR="${1:-$(dirname "${BASH_SOURCE[0]}")/sif}"
shift 2>/dev/null || true   # consume SIF_DIR arg if given; rest are tool names

ALL_TOOLS=(
    aai ani cog dbcan eggnog geneprop
    interpro kegg merops operon pfam pgap
    prodigal rasttk scoring synteny tcdb tigrfam uniprot
)

if [[ $# -gt 0 ]]; then
    TARGET_TOOLS=("$@")
else
    TARGET_TOOLS=("${ALL_TOOLS[@]}")
fi

# ── Pre-flight ────────────────────────────────────────────────────────────────
if ! command -v apptainer &>/dev/null && ! command -v singularity &>/dev/null; then
    echo "[error] Neither 'apptainer' nor 'singularity' found in PATH." >&2
    exit 1
fi
APPTAINER_CMD="$(command -v apptainer 2>/dev/null || command -v singularity)"

mkdir -p "$SIF_DIR"
echo "Pulling SIF images to: $SIF_DIR"
echo ""

# ── Pull loop ─────────────────────────────────────────────────────────────────
FAILED=()
for tool in "${TARGET_TOOLS[@]}"; do
    sif="$SIF_DIR/$tool.sif"
    src="docker://$REGISTRY/$tool:latest"

    if [[ -f "$sif" ]]; then
        echo "[skip] $tool.sif already exists"
        continue
    fi

    echo "[pull] $tool → $sif"
    if "$APPTAINER_CMD" pull "$sif" "$src"; then
        echo "[ok]   $tool"
    else
        echo "[FAIL] $tool — pull failed (image missing or auth required?)"
        FAILED+=("$tool")
    fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
echo "  Pull summary"
echo "══════════════════════════════════════════════════════"
pulled=$(( ${#TARGET_TOOLS[@]} - ${#FAILED[@]} ))
echo "  Pulled: $pulled / ${#TARGET_TOOLS[@]}"
if [[ "${#FAILED[@]}" -gt 0 ]]; then
    echo "  Failed: ${FAILED[*]}"
    echo ""
    echo "  If images are private, authenticate first:"
    echo "    apptainer registry login --username YOUR_GITHUB_USER docker://ghcr.io"
    exit 1
fi
echo ""
echo "  All SIF files are in: $SIF_DIR"
echo ""
echo "  To use in the pipeline, add to pipeline.conf:"
echo "    CONF_SIF_DIR=$SIF_DIR"
echo "    CONF_CONTAINER_RUNTIME=apptainer"
