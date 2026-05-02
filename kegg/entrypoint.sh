#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# KEGG / KofamScan container entrypoint — pipeline-standard interface
# Installed at /usr/local/bin/run inside the container.
#
# Interface:
#   run -i /input/org.faa -o /output -d /db [-t THREADS]
#
# Runs KofamScan in detail format and writes native output to /output/kegg.txt
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

usage() {
    cat <<'HELP_EOF'

KEGG Orthology annotation via KofamScan

USAGE
  docker run ... annotation/kegg:latest \
    -i /input/organism.faa -o /output -d /db [-t THREADS]

REQUIRED MOUNTS
  /input/organism.faa   Protein FASTA (.faa) — read-only
  /output/              Output directory — writable
  /db/                  KEGG database dir containing profiles/ and ko_list

REQUIRED OPTIONS
  -i FILE     Protein FASTA input file (inside container)
  -o DIR      Output directory         (inside container: /output)
  -d DIR      KEGG database directory  (inside container: /db)

OPTIONAL OPTIONS
  -t INT      CPU threads  [default: 1]
  --help      Show this help and exit

OUTPUTS  (written to /output)
  kegg.txt   — KofamScan detail format: * = above threshold

HELP_EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────
INPUT="" OUTPUT="" DBDIR="" THREADS=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i) INPUT="$2";   shift 2 ;;
        -o) OUTPUT="$2";  shift 2 ;;
        -d) DBDIR="$2";   shift 2 ;;
        -t) THREADS="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -z "$INPUT" || -z "$OUTPUT" || -z "$DBDIR" ]]; then
    echo "[kegg] ERROR: -i INPUT, -o OUTPUT, and -d DBDIR are required" >&2
    usage; exit 1
fi

if [[ ! -f "$INPUT" ]]; then
    echo "[kegg] ERROR: Input file not found: $INPUT" >&2
    exit 1
fi

if [[ ! -d "$DBDIR/profiles" || ! -f "$DBDIR/ko_list" ]]; then
    echo "[kegg] ERROR: KEGG DB not found at $DBDIR (need profiles/ and ko_list)" >&2
    exit 1
fi

mkdir -p "$OUTPUT"

# Skip if already complete
if [[ -s "$OUTPUT/kegg.txt" ]]; then
    echo "[kegg] Complete output already exists, skipping (delete manually to re-run)"
    exit 0
fi

# Write config.yml for exec_annotation
CONFIG="/tmp/kofamscan_config_$$.yml"
cat > "$CONFIG" <<YMLEOF
profile: ${DBDIR}/profiles
ko_list: ${DBDIR}/ko_list
cpu: ${THREADS}
format: detail
YMLEOF

echo "[kegg] Running KofamScan with $THREADS threads..."
exec_annotation \
    --config "$CONFIG" \
    -o "$OUTPUT/kegg.txt" \
    "$INPUT"

rm -f "$CONFIG"
echo "[kegg] KofamScan complete."

