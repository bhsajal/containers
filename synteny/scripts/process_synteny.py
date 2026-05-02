#!/usr/bin/env python3
"""
process_synteny.py — Detect synteny blocks from DIAMOND hits (runs inside container).

Input:
  --diamond-hits   /output/<organism>/diamond_hits.tsv   (DIAMOND blastp outfmt 6)
  --coords         /output/gene_coords.tsv               (built by build_index.py)
  --organism       query organism name
  --partners       comma-separated list of partner organism names to consider
  --out-dir        /output/<organism>/

Output:
  synteny_blocks.tsv   one row per syntenic block

Algorithm (microsynteny):
  For each (query_contig, ref_contig, partner_organism) triple:
    1. Collect all DIAMOND hits between q_contig and ref_contig.
    2. Sort by query genomic order (contig_rank).
    3. Scan for runs of ≥ MIN_BLOCK_GENES consecutive gene pairs where:
         - consecutive query genes are within MAX_GENE_GAP positions of each other
         - the corresponding ref genes are also consecutive (within MAX_GENE_GAP)
         - strand orientation is consistent across the run
    4. Each qualifying run is one synteny block.

Output columns:
  organism  partner_organism  block_id
  q_contig  q_start  q_end  q_gene_start  q_gene_end
  r_contig  r_start  r_end  r_gene_start  r_gene_end
  n_genes   strand_consistency  avg_identity
"""
from __future__ import annotations

import argparse
import csv
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple


# ── Tuneable parameters ────────────────────────────────────────────────────────
MIN_BLOCK_GENES = 3    # minimum genes to call a synteny block
MAX_GENE_GAP    = 5    # max allowed gap in contig_rank between consecutive block members


# ── Data structures ────────────────────────────────────────────────────────────

@dataclass
class GeneInfo:
    organism:    str
    gene_id:     str
    contig_id:   str
    start:       int
    end:         int
    strand:      str
    contig_rank: int   # 0-based order within contig, sorted by start


@dataclass
class Hit:
    q_gene:   str
    r_gene:   str
    pident:   float


@dataclass
class SyntenyBlock:
    organism:         str
    partner:          str
    block_id:         int
    q_contig:         str
    r_contig:         str
    q_start:          int   # genomic coord
    q_end:            int
    r_start:          int
    r_end:            int
    q_gene_start:     str   # first gene id
    q_gene_end:       str   # last gene id
    r_gene_start:     str
    r_gene_end:       str
    n_genes:          int
    strand_consistent: bool
    avg_identity:     float


# ── Argument parsing ───────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Detect synteny blocks from DIAMOND hits")
    p.add_argument("--diamond-hits", required=True)
    p.add_argument("--coords",       required=True)
    p.add_argument("--organism",     required=True)
    p.add_argument("--partners",     required=True,
                   help="Comma-separated list of partner organism names")
    p.add_argument("--out-dir",      required=True)
    return p.parse_args()


# ── Load gene coordinates ──────────────────────────────────────────────────────

def load_coords(coords_path: Path) -> Dict[str, GeneInfo]:
    """Returns {namespaced_gene_id: GeneInfo} where key = '<organism>@@<gene_id>'."""
    genes: Dict[str, GeneInfo] = {}
    with open(coords_path) as fh:
        reader = csv.DictReader(fh, delimiter='\t')
        for row in reader:
            key = f"{row['organism']}@@{row['gene_id']}"
            genes[key] = GeneInfo(
                organism    = row['organism'],
                gene_id     = row['gene_id'],
                contig_id   = row['contig_id'],
                start       = int(row['start']),
                end         = int(row['end']),
                strand      = row['strand'],
                contig_rank = int(row['contig_rank']),
            )
    return genes


# ── Load DIAMOND hits ──────────────────────────────────────────────────────────

def load_hits(hits_path: Path, query_org: str, partners: set) -> List[Hit]:
    """
    Load hits where qseqid is from query_org and sseqid is from a partner.
    Both IDs in diamond output are namespaced as <organism>@@<gene_id>.
    """
    hits: List[Hit] = []
    with open(hits_path) as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            cols = line.split('\t')
            if len(cols) < 8:
                continue
            qseqid, sseqid = cols[0], cols[1]
            pident = float(cols[2])

            # Namespace query ID if not already namespaced.
            # DIAMOND uses raw gene IDs for the query FAA, but subjects are
            # namespaced as <organism>@@<gene_id> by the DB build step.
            if '@@' not in qseqid:
                qseqid = f"{query_org}@@{qseqid}"

            if '@@' not in sseqid:
                continue
            q_org = qseqid.split('@@', 1)[0]
            s_org = sseqid.split('@@', 1)[0]

            if q_org != query_org:
                continue
            if s_org not in partners:
                continue

            hits.append(Hit(q_gene=qseqid, r_gene=sseqid, pident=pident))
    return hits


# ── Synteny block detection ────────────────────────────────────────────────────

def detect_blocks(
    query_org: str,
    partner: str,
    hits: List[Hit],
    genes: Dict[str, GeneInfo],
) -> List[SyntenyBlock]:
    """
    Detect synteny blocks between query_org and a single partner organism.
    """
    # Group hits by (q_contig, r_contig)
    # For each query gene keep best hit per r_contig (highest pident)
    best: Dict[Tuple[str, str, str], Hit] = {}  # (q_gene, q_contig, r_contig) → Hit
    for hit in hits:
        q_info = genes.get(hit.q_gene)
        r_info = genes.get(hit.r_gene)
        if q_info is None or r_info is None:
            continue
        if r_info.organism != partner:
            continue
        key = (hit.q_gene, q_info.contig_id, r_info.contig_id)
        if key not in best or hit.pident > best[key].pident:
            best[key] = hit

    # Group by (q_contig, r_contig)
    contig_pairs: Dict[Tuple[str, str], List[Tuple[GeneInfo, GeneInfo, float]]] = defaultdict(list)
    for (q_gene_id, q_contig, r_contig), hit in best.items():
        q_info = genes[hit.q_gene]
        r_info = genes[hit.r_gene]
        contig_pairs[(q_contig, r_contig)].append((q_info, r_info, hit.pident))

    blocks: List[SyntenyBlock] = []
    block_id = 0

    for (q_contig, r_contig), pairs in contig_pairs.items():
        # Sort by query contig_rank
        pairs.sort(key=lambda x: x[0].contig_rank)

        # Scan for synteny runs
        run: List[Tuple[GeneInfo, GeneInfo, float]] = [pairs[0]]

        def _flush_run(run: List[Tuple[GeneInfo, GeneInfo, float]]):
            nonlocal block_id
            if len(run) < MIN_BLOCK_GENES:
                return
            q_genes  = [r[0] for r in run]
            r_genes  = [r[1] for r in run]
            pidents  = [r[2] for r in run]
            # check strand consistency
            q_strands = {g.strand for g in q_genes}
            r_strands = {g.strand for g in r_genes}
            strand_ok = len(q_strands) == 1 and len(r_strands) == 1
            block_id += 1
            blocks.append(SyntenyBlock(
                organism          = query_org,
                partner           = partner,
                block_id          = block_id,
                q_contig          = q_contig,
                r_contig          = r_contig,
                q_start           = min(g.start for g in q_genes),
                q_end             = max(g.end   for g in q_genes),
                r_start           = min(g.start for g in r_genes),
                r_end             = max(g.end   for g in r_genes),
                q_gene_start      = q_genes[0].gene_id,
                q_gene_end        = q_genes[-1].gene_id,
                r_gene_start      = r_genes[0].gene_id,
                r_gene_end        = r_genes[-1].gene_id,
                n_genes           = len(run),
                strand_consistent = strand_ok,
                avg_identity      = sum(pidents) / len(pidents),
            ))

        for i in range(1, len(pairs)):
            prev_q, prev_r, _ = run[-1]
            curr_q, curr_r, _ = pairs[i]

            q_gap = curr_q.contig_rank - prev_q.contig_rank
            r_gap = abs(curr_r.contig_rank - prev_r.contig_rank)

            if q_gap <= MAX_GENE_GAP and r_gap <= MAX_GENE_GAP:
                run.append(pairs[i])
            else:
                _flush_run(run)
                run = [pairs[i]]

        _flush_run(run)

    return blocks


# ── Write output ───────────────────────────────────────────────────────────────

HEADER = [
    "organism", "partner_organism", "block_id",
    "q_contig", "q_start", "q_end", "q_gene_start", "q_gene_end",
    "r_contig", "r_start", "r_end", "r_gene_start", "r_gene_end",
    "n_genes", "strand_consistent", "avg_identity",
]


def write_blocks(blocks: List[SyntenyBlock], out_path: Path):
    with open(out_path, 'w', newline='') as fh:
        writer = csv.writer(fh, delimiter='\t')
        writer.writerow(HEADER)
        for b in blocks:
            writer.writerow([
                b.organism, b.partner, b.block_id,
                b.q_contig, b.q_start, b.q_end, b.q_gene_start, b.q_gene_end,
                b.r_contig, b.r_start, b.r_end, b.r_gene_start, b.r_gene_end,
                b.n_genes, b.strand_consistent, f"{b.avg_identity:.2f}",
            ])


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    args = parse_args()

    partners = {p.strip() for p in args.partners.split(',') if p.strip()}
    out_dir  = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"[process_synteny] Loading gene coordinates from {args.coords} ...")
    genes = load_coords(Path(args.coords))
    print(f"[process_synteny] Loaded {len(genes):,} gene entries")

    print(f"[process_synteny] Loading DIAMOND hits from {args.diamond_hits} ...")
    hits = load_hits(Path(args.diamond_hits), args.organism, partners)
    print(f"[process_synteny] {len(hits):,} hits (query={args.organism}, partners={len(partners)})")

    if not hits:
        print("[process_synteny] No hits found — writing empty synteny_blocks.tsv")
        write_blocks([], out_dir / "synteny_blocks.tsv")
        return

    all_blocks: List[SyntenyBlock] = []
    for partner in sorted(partners):
        partner_hits = [h for h in hits if genes.get(h.r_gene) and genes[h.r_gene].organism == partner]
        if not partner_hits:
            continue
        blocks = detect_blocks(args.organism, partner, partner_hits, genes)
        all_blocks.extend(blocks)
        print(f"[process_synteny]   {partner}: {len(blocks)} synteny blocks")

    out_path = out_dir / "synteny_blocks.tsv"
    write_blocks(all_blocks, out_path)
    print(f"[process_synteny] Wrote {len(all_blocks)} blocks → {out_path}")


if __name__ == "__main__":
    main()
