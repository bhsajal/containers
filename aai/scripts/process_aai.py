#!/usr/bin/env python3
"""
process_aai.py — Post-process CompareM aai_summary.tsv into closest_organisms.tsv.

CompareM aai_summary.tsv columns (tab-separated):
  Genome A  Genome B  # genes in A  # genes in B  # orthologs  AAI  Std AAI

CompareM names the genomes by their filename stem (without .faa extension),
which matches our organism directory names exactly.

Output closest_organisms.tsv columns:
  organism  rank  partner_organism  aai  shared_orthologs  total_genes_query
"""
from __future__ import annotations

import argparse
import csv
import sys
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Tuple


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--input",  required=True, help="CompareM aai_summary.tsv")
    p.add_argument("--output", required=True, help="Output closest_organisms.tsv")
    p.add_argument("--top-n",  type=int, default=5, help="Top N closest partners")
    return p.parse_args()


def main() -> None:
    args = parse_args()
    in_path  = Path(args.input)
    out_path = Path(args.output)
    top_n    = args.top_n

    # {organism: [(partner, aai, orthologs, total_query), ...]}
    hits: Dict[str, List[Tuple[str, float, int, int]]] = defaultdict(list)

    with open(in_path) as fh:
        reader = csv.reader(fh, delimiter="\t")
        for row in reader:
            # CompareM header starts with "#Genome A"; skip comments/headers
            if not row or row[0].startswith("#"):
                continue
            if len(row) < 6:
                continue
            # Actual column order from CompareM aai_summary.tsv:
            # 0: Genome A  1: Genes in A  2: Genome B  3: Genes in B
            # 4: # orthologous genes  5: Mean AAI  6: Std AAI  7: OF
            org_a  = row[0].strip()
            org_b  = row[2].strip()
            try:
                genes_a   = int(row[1])
                genes_b   = int(row[3])
                orthologs = int(row[4])
                aai       = float(row[5])
            except (ValueError, IndexError):
                continue

            # CompareM reports each pair once (A→B); add both directions
            hits[org_a].append((org_b, aai, orthologs, genes_a))
            hits[org_b].append((org_a, aai, orthologs, genes_b))

    if not hits:
        print("[process_aai] ERROR: no AAI pairs parsed from input", file=sys.stderr)
        sys.exit(1)

    rows_written = 0
    with open(out_path, "w", newline="") as fh:
        writer = csv.writer(fh, delimiter="\t")
        writer.writerow(["organism", "rank", "partner_organism", "aai", "shared_orthologs", "total_genes_query"])
        for org in sorted(hits.keys()):
            partners = sorted(hits[org], key=lambda x: x[1], reverse=True)[:top_n]
            for rank, (partner, aai, orthologs, total) in enumerate(partners, start=1):
                writer.writerow([org, rank, partner, round(aai, 4), orthologs, total])
                rows_written += 1

    print(f"[process_aai] Wrote {rows_written} rows → {out_path}")
    print(f"[process_aai] {len(hits)} organisms with at least one AAI partner")


if __name__ == "__main__":
    main()
