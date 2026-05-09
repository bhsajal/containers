#!/usr/bin/env bash
# TMbed — transmembrane segment and signal peptide predictor (Apache-2.0)
# https://github.com/BernhoferM/TMbed
# Usage: -i <input.faa> -o <output_dir> -t <threads>
#
# Mounts: /models — persistent dir for the ProtT5 model (~2.25 GB on first run)
# Output format 1 (3-line per protein: header, sequence, labels):
#   B/b=TM beta strand, H/h=TM alpha helix, S=signal peptide,
#   i=non-TM inside, o=non-TM outside
set -euo pipefail

INPUT="" OUTPUT_DIR="" THREADS=4
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i) INPUT="$2";      shift 2 ;;
        -o) OUTPUT_DIR="$2"; shift 2 ;;
        -t) THREADS="$2";    shift 2 ;;
        *)  shift ;;
    esac
done

mkdir -p "$OUTPUT_DIR" /models

tmbed predict \
    -f "${INPUT}" \
    -p "${OUTPUT_DIR}/tmbed.pred" \
    --no-use-gpu \
    --model-dir /models \
    --out-format 1
