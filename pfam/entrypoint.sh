#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# CONTAINER ENTRYPOINT — Pfam (HMMER hmmscan against Pfam-A)
# Placed at /usr/local/bin/run inside the container.
#
# Accepts the pipeline-standard interface:
#   run -i /input/org.faa -o /output -d /db [-t THREADS]
#
# Translates to:
#   hmmscan --domtblout /output/pfam_domtbl.out --cpu THREADS
#           --domE 1e-5 /db/Pfam-A.hmm /input/org.faa
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

usage() {
    cat <<'HELP_EOF'

Pfam — Protein domain annotation via HMMER hmmscan against Pfam-A

USAGE
  docker run ... annotation/pfam:latest \
    -i /input/organism.faa -o /output -d /db [-t THREADS]

REQUIRED MOUNTS
  /input/organism.faa   Protein FASTA (.faa) — read-only
  /output/              Output directory — writable
  /db/                  Pfam database dir containing Pfam-A.hmm + .h3* index files

REQUIRED OPTIONS
  -i FILE     Protein FASTA input file (inside container)
  -o DIR      Output directory         (inside container: /output)
  -d DIR      Pfam database directory  (inside container: /db)

OPTIONAL OPTIONS
  -t INT      CPU threads  [default: 1]
  --help      Show this help and exit

OUTPUTS  (written to /output)
  pfam_domtbl.out   — hmmscan domain table (parsed by process.py)
  pfam.log          — full hmmscan log

THRESHOLD
  Uses Pfam curated gathering thresholds (--cut_ga). Per-family bit-score
  cutoffs set by Pfam curators. No arbitrary e-value cutoff needed.

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

HMM="$DBDIR/Pfam-A.hmm"
if [[ ! -f "$HMM" ]]; then
    echo "[pfam] ERROR: Pfam-A.hmm not found in $DBDIR" >&2
    exit 1
fi

mkdir -p "$OUTPUT"

# Skip if already complete
if [[ -s "$OUTPUT/pfam_domtbl.out" ]]; then
    echo "[pfam] Complete output already exists, skipping (delete manually to re-run)"
    exit 0
fi

echo "[pfam] Running hmmscan with $THREADS threads (--cut_ga --nobias --F1 0.005 --F2 1e-5)..."
hmmscan \
    --cut_ga \
    --nobias \
    --F1 0.005 \
    --F2 1e-5 \
    --domtblout "$OUTPUT/pfam_domtbl.out" \
    --noali \
    --cpu "$THREADS" \
    "$HMM" \
    "$INPUT" \
    > "$OUTPUT/pfam.log" 2>&1
