#!/usr/bin/env bash
# tmhmm.py — MIT reimplementation of TMHMM2 (redistributable)
# Usage: -i <input.faa> -o <output_dir> -t <threads>
#
# This runner uses tmhmm.py's Python API directly so we avoid creating
# large intermediate .plot/.annotation files for every protein.
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
mkdir -p "$OUTPUT_DIR"
OUTPUT="$OUTPUT_DIR/tmhmm.tsv"

python3 - "${INPUT}" "${OUTPUT}" <<'PY'
import os
import sys

input_faa = sys.argv[1]
output_tsv = sys.argv[2]

try:
    import tmhmm
    from tmhmm.model import parse
    from tmhmm.api import predict
except Exception as exc:
    with open(output_tsv, "w", encoding="utf-8") as out:
        out.write("protein_id\tstart\tend\ttopology\n")
        out.write(f"skipped\t0\t0\ttmhmm import failed: {exc}\n")
    raise SystemExit(0)

app_dir = os.path.dirname(tmhmm.__path__[0])
default_model = os.path.join(app_dir, "tmhmm", "TMHMM2.0.model")

pretty = {
    "i": "inside",
    "M": "transmembrane helix",
    "o": "outside",
    "O": "outside",
}

def summarize(path: str):
    if not path:
        return
    start = 0
    prev = path[0]
    for idx, state in enumerate(path[1:], 1):
        if state != prev:
            yield start, idx - 1, prev
            start = idx
            prev = state
    yield start, len(path) - 1, prev

def parse_fasta(path):
    header = None
    seq_parts = []
    with open(path, "r", encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith(">"):
                if header is not None:
                    yield header, "".join(seq_parts)
                header = line[1:]
                seq_parts = []
            else:
                seq_parts.append(line)
    if header is not None:
        yield header, "".join(seq_parts)

with open(default_model, "r", encoding="utf-8") as fh:
    header, model = parse(fh)

with open(output_tsv, "w", encoding="utf-8") as out:
    out.write("protein_id\tstart\tend\ttopology\n")
    for fasta_header, sequence in parse_fasta(input_faa):
        protein_id = fasta_header.split(None, 1)[0]
        path, _posterior = predict(sequence, header, model)
        for start, end, state in summarize(path):
            topo = pretty.get(state, state)
            out.write(f"{protein_id}\t{start}\t{end}\t{topo}\n")
PY
