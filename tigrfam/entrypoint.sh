#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# CONTAINER ENTRYPOINT — TIGRFAMs (HMMER hmmscan against TIGRFAMs_15.0_HMM.LIB)
# Placed at /usr/local/bin/run inside the container.
#
# Accepts the pipeline-standard interface:
#   run -i /input/org.faa -o /output -d /db [-t THREADS]
#
# Translates to:
#   hmmscan --cut_tc --noali --domtblout /output/tigrfam_domtbl.out
#           --cpu THREADS /db/TIGRFAMs_15.0_HMM.LIB /input/org.faa
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

usage() {
    cat <<'HELP_EOF'

TIGRFAMs — Protein functional role annotation via HMMER hmmscan

USAGE
  docker run ... annotation/tigrfam:latest \
    -i /input/organism.faa -o /output -d /db [-t THREADS]

REQUIRED MOUNTS
  /input/organism.faa   Protein FASTA (.faa) — read-only
  /output/              Output directory — writable
  /db/                  TIGRFAMs dir containing TIGRFAMs_15.0_HMM.LIB + .h3* index files

REQUIRED OPTIONS
  -i FILE     Protein FASTA input file (inside container)
  -o DIR      Output directory         (inside container: /output)
  -d DIR      TIGRFAMs database directory (inside container: /db)

OPTIONAL OPTIONS
  -t INT      CPU threads  [default: 1]
  --help      Show this help and exit

OUTPUTS  (written to /output)
  tigrfam_domtbl.out   — hmmscan domain table (parsed by process.py)
  tigrfam.log          — full hmmscan log

THRESHOLD
  Uses TIGRFAMs trusted cutoffs (--cut_tc). Per-family bit-score
  cutoffs curated by JCVI/NCBI. No arbitrary e-value cutoff needed.

HELP_EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────
INPUT="" OUTPUT="" DBDIR="" THREADS=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i) INPUT="$2";  shift 2 ;;
        -o) OUTPUT="$2"; shift 2 ;;
        -d) DBDIR="$2";  shift 2 ;;
        -t) THREADS="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -z "$INPUT" || -z "$OUTPUT" || -z "$DBDIR" ]]; then
    usage; exit 1
fi

HMM="$DBDIR/TIGRFAMs_15.0_HMM.LIB"
if [[ ! -f "$HMM" ]]; then
    echo "[tigrfam] ERROR: TIGRFAMs_15.0_HMM.LIB not found in $DBDIR" >&2
    exit 1
fi

mkdir -p "$OUTPUT"

# Skip if already complete
if [[ -s "$OUTPUT/tigrfam_domtbl.out" ]]; then
    echo "[tigrfam] Complete output already exists, skipping (delete manually to re-run)"
    exit 0
fi

echo "[tigrfam] Running hmmscan with $THREADS threads (--cut_tc --noali)..."
hmmscan \
    --cut_tc \
    --noali \
    --domtblout "$OUTPUT/tigrfam_domtbl.out" \
    --cpu "$THREADS" \
    "$HMM" \
    "$INPUT" \
    > "$OUTPUT/tigrfam.log" 2>&1
