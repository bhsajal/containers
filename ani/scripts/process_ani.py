#!/usr/bin/env python3
"""
process_ani.py — Post-process fastANI output into closest-organism table.

fastANI --matrix output format (5 columns, tab-separated):
  query_path  ref_path  ani  shared_fragments  total_fragments

Writes closest_organisms.tsv with columns:
  organism  rank  partner_organism  ani  shared_fragments  total_fragments
"""
from __future__ import annotations

import argparse
import csv
import os
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Tuple


def organism_name(fna_path: str) -> str:
    """Extract organism name from a .fna file path (basename without .fna)."""
    return Path(fna_path).stem


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--input",  required=True, help="Raw fastANI output file")
    p.add_argument("--output", required=True, help="closest_organisms.tsv output path")
    p.add_argument("--top-n",  type=int, default=5, help="Number of closest organisms to report per genome")
    return p.parse_args()


def main() -> None:
    args = parse_args()
    raw_path  = Path(args.input)
    out_path  = Path(args.output)
    top_n     = args.top_n

    # Parse fastANI output
    # {organism: [(ani, shared, total, partner), ...]}
    hits: Dict[str, List[Tuple[float, int, int, str]]] = defaultdict(list)

    if not raw_path.exists():
        print(f"[process_ani] ERROR: input not found: {raw_path}")
        raise SystemExit(1)

    with open(raw_path) as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            cols = line.split("\t")
            if len(cols) < 5:
                continue
            query_path = cols[0]
            ref_path   = cols[1]
            try:
                ani    = float(cols[2])
                shared = int(cols[3])
                total  = int(cols[4])
            except ValueError:
                continue

            query_org = organism_name(query_path)
            ref_org   = organism_name(ref_path)

            # Skip self-comparisons
            if query_org == ref_org:
                continue

            hits[query_org].append((ani, shared, total, ref_org))

    # Sort by ANI descending, take top N
    out_path.parent.mkdir(parents=True, exist_ok=True)
    rows_written = 0

    with open(out_path, "w", newline="") as fh:
        writer = csv.writer(fh, delimiter="\t")
        writer.writerow(["organism", "rank", "partner_organism", "ani", "shared_fragments", "total_fragments"])

        for org in sorted(hits.keys()):
            ranked = sorted(hits[org], key=lambda x: x[0], reverse=True)[:top_n]
            for rank, (ani, shared, total, partner) in enumerate(ranked, start=1):
                writer.writerow([org, rank, partner, round(ani, 4), shared, total])
                rows_written += 1

    print(f"[process_ani] Wrote {rows_written} rows → {out_path}")
    n_orgs = len(hits)
    print(f"[process_ani] {n_orgs} organisms with top-{top_n} closest partners recorded")


if __name__ == "__main__":
    main()
