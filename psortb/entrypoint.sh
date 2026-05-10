#!/usr/bin/env bash
# PSORTb v3 — prokaryote subcellular localization predictor
# Usage: -i <input.faa> -o <output_dir> -t <threads> [-k n|p|a]
#   gram: n=negative (default), p=positive, a=archaea
set -euo pipefail

INPUT="" OUTPUT_DIR="" THREADS=4 GRAM="n"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i) INPUT="$2";      shift 2 ;;
        -o) OUTPUT_DIR="$2"; shift 2 ;;
        -t) THREADS="$2";    shift 2 ;;
        -k) GRAM="$2";       shift 2 ;;
        *)  shift ;;
    esac
done

mkdir -p "$OUTPUT_DIR"
export BLASTDIR="${BLASTDIR:-/usr/bin}"

perl /usr/local/bin/psortb3_patched.pl \
    -"${GRAM}" -o terse "${INPUT}" \
    > "${OUTPUT_DIR}/psortb.txt" 2>"${OUTPUT_DIR}/psortb_err.txt" || true
