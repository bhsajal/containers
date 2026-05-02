#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# Genome Properties container entrypoint — pipeline-standard interface
# Installed at /usr/local/bin/run inside the container.
#
# This container is a NO-OP: all assignment logic lives in process.py on
# the host.  The container satisfies the pipeline interface by creating
# /output and exiting 0.  process.py derives the tigrfam domtblout path
# from the native output directory it receives as --input.
#
# Interface:
#   run -i /input/org.faa -o /output -d /db [-t THREADS]
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

usage() {
    cat <<'HELP_EOF'

Genome Properties — Whole-genome biological property assignment

USAGE
  docker run ... annotation/geneprop:latest \
    -i /input/organism.faa -o /output -d /db [-t THREADS]

REQUIRED MOUNTS
  /input/organism.faa   Protein FASTA (.faa) — accepted but not used
  /output/              Output directory — writable
  /db/                  Genome Properties repo (clone of ebi-pf-team/genome-properties)
                        Must contain: flatfiles/

NOTE
  All assignment logic is implemented in process.py on the host.
  This container is a no-op that creates /output and exits 0.
  The tigrfam domtblout is read directly by process.py from the
  sibling tigrfam output directory.

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

if [[ -z "$OUTPUT" ]]; then
    echo "[geneprop] ERROR: -o OUTPUT is required" >&2
    usage; exit 1
fi

mkdir -p "$OUTPUT"
echo "[geneprop] Container no-op complete. process.py will run genome-properties assignment."
