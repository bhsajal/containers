#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# RAST-TK / BV-BRC container entrypoint
#
# Installed at /usr/local/bin/run inside the container.
# Runs the full FASTA → annotated outputs pipeline:
#
#     rast-create-genome  (FASTA ─► Genome Typed Object JSON)
#       │
#       ▼
#     rast-process-genome (annotate the GTO with SEED subsystems / RAST features)
#       │
#       ▼
#     rast-export-genome  (GTO ─► .faa, .gff, .gbk)
#
# Usage (from host):
#   docker run --rm --platform linux/amd64 \
#       -v <input_dir>:/input:ro \
#       -v <output_root>:/output:rw \
#       ghcr.io/bhsajal/rasttk:latest \
#       -i /input/<organism>.fna -o /output \
#       [--scientific-name "Genus species"] \
#       [--genetic-code 11] [--domain Bacteria]
#
# Outputs are written to:
#   /output/<organism>/native/gene-calls/<organism>.{json,faa,gff,gbk}
# where <organism> = basename of -i with .fna/.fasta/.fa stripped.
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

usage() {
    cat <<'HELP_EOF'

RAST-TK / BV-BRC — Prokaryotic genome annotation via the SEED subsystem framework

USAGE
  run -i INPUT.fna -o OUTPUT_ROOT [OPTIONS]

REQUIRED
  -i, --input FILE          Input genome FASTA (.fna / .fasta / .fa)
  -o, --output DIR          Output root directory.
                            Files land in <DIR>/<organism>/native/gene-calls/

OPTIONS
  --scientific-name NAME    Organism scientific name. Default: derived from
                            the input filename (underscores → spaces, _GCF_*
                            suffix stripped).
  --genetic-code INT        Genetic code table. Default: 11
  --domain TEXT             Domain: Bacteria | Archaea. Default: Bacteria
  -h, --help                Show this help

OUTPUTS  (under <OUTPUT_ROOT>/<organism>/native/gene-calls/)
  <organism>.json   RAST-annotated Genome Typed Object (intermediate)
  <organism>.faa    Predicted protein sequences (FASTA)
  <organism>.gff    Feature annotations (GFF3)
  <organism>.gbk    GenBank format

MOUNT POINTS
  /input/    Genome FASTA directory (read-only)
  /output/   Output root directory  (read-write)
  /db/       SEED subsystem database  (optional, for offline mode)

HELP_EOF
}

if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

INPUT=""
OUTPUT_ROOT=""
SCI_NAME=""
GENETIC_CODE="11"
DOMAIN="Bacteria"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--input)            INPUT="$2";          shift 2 ;;
        -o|--output)           OUTPUT_ROOT="$2";    shift 2 ;;
        --scientific-name)     SCI_NAME="$2";       shift 2 ;;
        --genetic-code)        GENETIC_CODE="$2";   shift 2 ;;
        --domain)              DOMAIN="$2";         shift 2 ;;
        -h|--help)             usage; exit 0 ;;
        *)
            echo "[rasttk] ERROR: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

[[ -z "$INPUT" ]]       && { echo "[rasttk] ERROR: -i/--input is required"  >&2; exit 2; }
[[ -z "$OUTPUT_ROOT" ]] && { echo "[rasttk] ERROR: -o/--output is required" >&2; exit 2; }
[[ ! -f "$INPUT" ]]     && { echo "[rasttk] ERROR: input not found: $INPUT" >&2; exit 1; }

# Derive organism name from input filename (strip extension)
fna_basename="$(basename "$INPUT")"
ORGANISM="${fna_basename%.*}"

# Derive scientific name if not provided: replace underscores with spaces,
# strip any _GCF_* / _GCA_* suffix.
if [[ -z "$SCI_NAME" ]]; then
    SCI_NAME="$(printf '%s' "$ORGANISM" | sed -E 's/_GC[FA]_.*$//; s/_/ /g')"
    [[ -z "$SCI_NAME" ]] && SCI_NAME="$ORGANISM"
fi

OUT_DIR="$OUTPUT_ROOT/$ORGANISM/native/gene-calls"
mkdir -p "$OUT_DIR"

GTO_JSON="$OUT_DIR/$ORGANISM.json"

echo "[rasttk] Organism        : $ORGANISM"
echo "[rasttk] Scientific name : $SCI_NAME"
echo "[rasttk] Genetic code    : $GENETIC_CODE"
echo "[rasttk] Domain          : $DOMAIN"
echo "[rasttk] Input FASTA     : $INPUT"
echo "[rasttk] Output dir      : $OUT_DIR"

# ── Step 1: FASTA → GTO (no network — incremental local pipeline) ─────────────
# rast-process-genome calls a remote BV-BRC API; instead we run each step
# locally using the incremental commands that work entirely offline.
echo "[rasttk] rast-create-genome ..."
rast-create-genome \
    --scientific-name "$SCI_NAME" \
    --genetic-code   "$GENETIC_CODE" \
    --domain         "$DOMAIN" \
    --contigs        "$INPUT" \
  > "$GTO_JSON"

echo "[rasttk] rast-call-features-rRNA-SEED ..."
rast-call-features-rRNA-SEED          < "$GTO_JSON" > "$GTO_JSON.tmp" && mv "$GTO_JSON.tmp" "$GTO_JSON"

echo "[rasttk] rast-call-features-tRNA-trnascan ..."
rast-call-features-tRNA-trnascan      < "$GTO_JSON" > "$GTO_JSON.tmp" && mv "$GTO_JSON.tmp" "$GTO_JSON"

echo "[rasttk] rast-call-features-repeat-region-SEED ..."
rast-call-features-repeat-region-SEED < "$GTO_JSON" > "$GTO_JSON.tmp" && mv "$GTO_JSON.tmp" "$GTO_JSON"

echo "[rasttk] rast-call-features-selenoprotein ..."
rast-call-features-selenoprotein      < "$GTO_JSON" > "$GTO_JSON.tmp" && mv "$GTO_JSON.tmp" "$GTO_JSON"

echo "[rasttk] rast-call-features-pyrrolysoprotein ..."
rast-call-features-pyrrolysoprotein   < "$GTO_JSON" > "$GTO_JSON.tmp" && mv "$GTO_JSON.tmp" "$GTO_JSON"

echo "[rasttk] rast-call-features-crispr ..."
rast-call-features-crispr             < "$GTO_JSON" > "$GTO_JSON.tmp" && mv "$GTO_JSON.tmp" "$GTO_JSON"

echo "[rasttk] rast-call-features-CDS-prodigal ..."
rast-call-features-CDS-prodigal       < "$GTO_JSON" > "$GTO_JSON.tmp" && mv "$GTO_JSON.tmp" "$GTO_JSON"

echo "[rasttk] rast-call-features-CDS-glimmer3 ..."
rast-call-features-CDS-glimmer3       < "$GTO_JSON" > "$GTO_JSON.tmp" && mv "$GTO_JSON.tmp" "$GTO_JSON"

echo "[rasttk] rast-annotate-proteins-kmer-v2 ..."
rast-annotate-proteins-kmer-v2        < "$GTO_JSON" > "$GTO_JSON.tmp" && mv "$GTO_JSON.tmp" "$GTO_JSON"

echo "[rasttk] rast-annotate-proteins-kmer-v1 -H ..."
rast-annotate-proteins-kmer-v1 -H     < "$GTO_JSON" > "$GTO_JSON.tmp" && mv "$GTO_JSON.tmp" "$GTO_JSON"

echo "[rasttk] rast-resolve-overlapping-features ..."
rast-resolve-overlapping-features     < "$GTO_JSON" > "$GTO_JSON.tmp" && mv "$GTO_JSON.tmp" "$GTO_JSON"

# ── Step 2: Exports ───────────────────────────────────────────────────────────
echo "[rasttk] rast-export-genome → protein_fasta"
rast-export-genome --input "$GTO_JSON" protein_fasta > "$OUT_DIR/$ORGANISM.faa"

echo "[rasttk] rast-export-genome → gff"
rast-export-genome --input "$GTO_JSON" gff           > "$OUT_DIR/$ORGANISM.gff"

echo "[rasttk] rast-export-genome → genbank"
rast-export-genome --input "$GTO_JSON" genbank       > "$OUT_DIR/$ORGANISM.gbk"

echo "[rasttk] done."
