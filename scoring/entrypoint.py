#!/usr/bin/env python3
"""
scoring/entrypoint.py — Placeholder scoring stage

Accepts the labeled.tsv from stageD/labeling.
Currently passes input through to output/scores.tsv with a PLACEHOLDER_SCORE
column of 0.  Scoring logic will be implemented in a future release.

Usage (from container):
    python3 entrypoint.py -i /input/<org>.tsv -o /output -t <threads>
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Scoring stage (placeholder)")
    p.add_argument("-i", "--input",   required=True, help="Path to labeled.tsv")
    p.add_argument("-o", "--output",  required=True, help="Output directory")
    p.add_argument("-t", "--threads", type=int, default=1, help="(reserved)")
    return p.parse_args()


def main() -> None:
    args = parse_args()
    in_path  = Path(args.input)
    out_dir  = Path(args.output)
    out_dir.mkdir(parents=True, exist_ok=True)

    if not in_path.exists():
        print(f"[scoring] ERROR: input not found: {in_path}", file=sys.stderr)
        sys.exit(1)

    print("[scoring] WARNING: Scoring stage is a placeholder — no scores computed yet.",
          file=sys.stderr)

    df = pd.read_csv(in_path, sep="\t", low_memory=False)
    df["PLACEHOLDER_SCORE"] = 0.0

    out_path = out_dir / "scores.tsv"
    df.to_csv(out_path, sep="\t", index=False)
    print(f"[scoring] Written {len(df)} rows → {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
