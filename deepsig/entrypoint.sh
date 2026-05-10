#!/usr/bin/env bash
# DeepSig — GPL-3 signal peptide predictor for prokaryotes
# Usage: -i <input.faa> -o <output_dir> -t <threads> [-k GRAM-|GRAM+|ARCH]
set -euo pipefail

INPUT="" OUTPUT_DIR="" THREADS=4 ORG="GRAM-"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i) INPUT="$2";      shift 2 ;;
        -o) OUTPUT_DIR="$2"; shift 2 ;;
        -t) THREADS="$2";    shift 2 ;;
        -k) ORG="$2";        shift 2 ;;
        *)  shift ;;
    esac
done

# Map pipeline gram convention to deepsig -k values
case "${ORG}" in
    GRAM-|gramn) DSORG="gramn" ;;
    GRAM+|gramp) DSORG="gramp" ;;
    ARCH|euk)    DSORG="euk"   ;;
    *)           DSORG="gramn" ;;
esac

mkdir -p "$OUTPUT_DIR"
deepsig -f "${INPUT}" -o "${OUTPUT_DIR}/deepsig.gff3" -k "${DSORG}"
