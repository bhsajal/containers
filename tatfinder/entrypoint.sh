#!/usr/bin/env bash
set -euo pipefail
# tatfinder entrypoint — standard pipeline interface
# Usage: -i <input.faa> -o <output_dir> -t <threads>

INPUT="" OUTPUT_DIR="" THREADS=4
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i) INPUT="$2";      shift 2 ;;
        -o) OUTPUT_DIR="$2"; shift 2 ;;
        -t) THREADS="$2";    shift 2 ;;
        *)  shift ;;
    esac
done

mkdir -p "$OUTPUT_DIR"

if [[ ! -f "/opt/tatfinder/repo/tat_find.pl" ]]; then
    echo -e "protein_id\ttat_signal\tmotif_start\tmotif\twindow_seq" > "$OUTPUT_DIR/tatfinder.tsv"
    echo "[tatfinder] ERROR: tat_find.pl not found in image" >&2
    exit 1
fi

perl /opt/tatfinder/repo/tat_find.pl "$INPUT" > "$OUTPUT_DIR/tatfinder.tsv"
