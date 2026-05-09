#!/usr/bin/env python3
"""
process_clinker.py — Parse clinker alignments.csv → synteny_links.tsv

The clinker -o output (with -dl "," -dc 4) has the following structure:

    ClusterA vs ClusterB
    --------------------
    gene1,gene2,0.8765,0.9012
    gene3,gene4,0.7230,0.8100

    ClusterA vs ClusterC
    --------------------
    ...

This script flattens all blocks into a single TSV with columns:
    query_cluster, ref_cluster, query_gene, ref_gene, identity, similarity

Usage:
    python3 process_clinker.py \\
        --alignments native/alignments.csv \\
        --organism   <query_organism_name> \\
        --out        native/synteny_links.tsv
"""

import argparse
import csv
import sys
from pathlib import Path


def parse_alignments(path: Path):
    """Yield (query_cluster, ref_cluster, query_gene, ref_gene, identity, similarity)
    tuples from a clinker alignments file."""

    query_cluster = None
    ref_cluster = None
    in_block = False

    with open(path, "r", encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()

            if not line:
                # blank line between blocks
                in_block = False
                query_cluster = None
                ref_cluster = None
                continue

            # Detect alignment header: "ClusterA vs ClusterB"
            if " vs " in line and not line.startswith("-"):
                parts = line.split(" vs ", 1)
                query_cluster = parts[0].strip()
                ref_cluster = parts[1].strip()
                in_block = False  # next non-dash line will be data
                continue

            # Detect separator line (all dashes)
            if line.startswith("-") and set(line) <= {"-"}:
                in_block = True
                continue

            # Data line
            if in_block and query_cluster and ref_cluster:
                cols = line.split(",")
                if len(cols) < 4:
                    continue  # malformed row — skip
                query_gene = cols[0].strip()
                ref_gene = cols[1].strip()
                try:
                    identity = float(cols[2].strip())
                    similarity = float(cols[3].strip())
                except ValueError:
                    continue
                yield (query_cluster, ref_cluster,
                       query_gene, ref_gene, identity, similarity)


def main():
    ap = argparse.ArgumentParser(
        description="Parse clinker alignments.csv → synteny_links.tsv"
    )
    ap.add_argument("--alignments", required=True,
                    help="Path to clinker alignments file (output of clinker -o)")
    ap.add_argument("--organism", required=True,
                    help="Query organism name (used to identify query-side clusters)")
    ap.add_argument("--out", required=True,
                    help="Output TSV path")
    args = ap.parse_args()

    aln_path = Path(args.alignments)
    out_path = Path(args.out)

    if not aln_path.exists():
        print(f"[process_clinker] ERROR: alignments file not found: {aln_path}",
              file=sys.stderr)
        sys.exit(1)

    out_path.parent.mkdir(parents=True, exist_ok=True)

    FIELDNAMES = [
        "query_cluster", "ref_cluster",
        "query_gene", "ref_gene",
        "identity", "similarity",
    ]

    n_rows = 0
    with open(out_path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=FIELDNAMES, delimiter="\t")
        writer.writeheader()

        for (qc, rc, qg, rg, ident, sim) in parse_alignments(aln_path):
            # Normalise direction: always put query organism first if present
            if rc == args.organism and qc != args.organism:
                qc, rc = rc, qc
                qg, rg = rg, qg

            writer.writerow({
                "query_cluster": qc,
                "ref_cluster": rc,
                "query_gene": qg,
                "ref_gene": rg,
                "identity": round(ident, 4),
                "similarity": round(sim, 4),
            })
            n_rows += 1

    print(f"[process_clinker] Wrote {n_rows} links → {out_path}")


if __name__ == "__main__":
    main()
