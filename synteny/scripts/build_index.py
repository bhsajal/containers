#!/usr/bin/env python3
"""
build_index.py — Build shared resources for synteny analysis (runs inside container).

1. Scans all organism directories in --rasttk-dir (looks for gene_calls/<org>.gff).
2. Parses each GFF to extract CDS features with coordinates.
3. Assigns per-contig genomic order ranks (0-based, sorted by start).
4. Writes --coords-out (gene_coords.tsv):
     organism, gene_id, contig_id, start, end, strand, contig_rank
5. Writes --faa-out (all_proteins.faa):
     Each FAA entry namespaced as ><organism>@@<original_gene_id> description
     (double-@@ used as separator since gene IDs may contain single |)
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Optional, Tuple


# ── Argument parsing ──────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Build synteny coordinate index and combined FAA")
    p.add_argument("--rasttk-dir",        required=True,  help="RASTtk output root directory")
    p.add_argument("--coords-out",        required=True,  help="Output: gene_coords.tsv")
    p.add_argument("--faa-out",           required=True,  help="Output: all_proteins.faa (namespaced)")
    p.add_argument("--organisms",         default=None,
                   help="Comma-separated list of organism names to include (default: all)")
    p.add_argument("--coords-skip-if-exists", action="store_true",
                   help="Skip writing coords-out if it already exists (faa-out still written)")
    return p.parse_args()


# ── GFF parsing ───────────────────────────────────────────────────────────────

ID_RE = re.compile(r'(?:^|;)ID=([^;]+)')


def parse_gff_cds(gff_path: Path) -> List[Tuple[str, str, int, int, str]]:
    """
    Parse CDS features from a GFF3 file.
    Returns list of (gene_id, contig, start, end, strand).
    start/end are 1-based inclusive (GFF3 convention).
    """
    records = []
    try:
        with open(gff_path) as fh:
            for line in fh:
                if line.startswith('#') or not line.strip():
                    continue
                cols = line.rstrip('\n').split('\t')
                if len(cols) < 9:
                    continue
                feature_type = cols[2]
                if feature_type not in ('CDS', 'gene'):
                    continue
                contig  = cols[0]
                start   = int(cols[3])
                end     = int(cols[4])
                strand  = cols[6] if cols[6] in ('+', '-') else '+'
                attrs   = cols[8]
                m = ID_RE.search(attrs)
                if not m:
                    continue
                gene_id = m.group(1).strip()
                records.append((gene_id, contig, start, end, strand))
    except OSError as exc:
        print(f"[build_index] WARNING: cannot read {gff_path}: {exc}", file=sys.stderr)
    return records


# ── FAA parsing ───────────────────────────────────────────────────────────────

def iter_faa(faa_path: Path):
    """Yield (header_line_without_gt, sequence) pairs from a FASTA file."""
    header: Optional[str] = None
    seq_parts: List[str] = []
    try:
        with open(faa_path) as fh:
            for line in fh:
                line = line.rstrip('\n')
                if line.startswith('>'):
                    if header is not None:
                        yield header, ''.join(seq_parts)
                    header = line[1:]
                    seq_parts = []
                elif header is not None:
                    seq_parts.append(line)
        if header is not None:
            yield header, ''.join(seq_parts)
    except OSError as exc:
        print(f"[build_index] WARNING: cannot read {faa_path}: {exc}", file=sys.stderr)


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    args = parse_args()
    rasttk_dir = Path(args.rasttk_dir)
    coords_out  = Path(args.coords_out)
    faa_out     = Path(args.faa_out)

    coords_out.parent.mkdir(parents=True, exist_ok=True)
    faa_out.parent.mkdir(parents=True, exist_ok=True)

    # Discover organism directories
    org_dirs = sorted(
        d for d in rasttk_dir.iterdir()
        if d.is_dir() and (d / 'gene_calls').is_dir()
    )
    if not org_dirs:
        print(f"[build_index] ERROR: No organism directories found in {rasttk_dir}", file=sys.stderr)
        sys.exit(1)

    # Filter to requested organisms if --organisms supplied
    if args.organisms:
        allowed = {o.strip() for o in args.organisms.split(',') if o.strip()}
        org_dirs = [d for d in org_dirs if d.name in allowed]
        if not org_dirs:
            print(f"[build_index] ERROR: None of the requested organisms found in {rasttk_dir}", file=sys.stderr)
            sys.exit(1)

    print(f"[build_index] Found {len(org_dirs)} organism directories", file=sys.stderr)

    # Collect all coords
    # Structure: {organism: [(gene_id, contig, start, end, strand)]}
    all_records: Dict[str, List[Tuple[str, str, int, int, str]]] = {}

    for org_dir in org_dirs:
        organism = org_dir.name
        gff_path = org_dir / 'gene_calls' / f'{organism}.gff'
        if not gff_path.exists():
            print(f"[build_index] WARNING: GFF not found: {gff_path}", file=sys.stderr)
            continue
        records = parse_gff_cds(gff_path)
        if not records:
            print(f"[build_index] WARNING: No CDS features parsed from {gff_path}", file=sys.stderr)
            continue
        all_records[organism] = records

    print(f"[build_index] Parsed GFF for {len(all_records)} organisms", file=sys.stderr)

    # ── Write gene_coords.tsv ──────────────────────────────────────────────────
    if not (args.coords_skip_if_exists and coords_out.exists()):
        total_genes = 0
        with open(coords_out, 'w') as coords_fh:
            coords_fh.write('organism\tgene_id\tcontig_id\tstart\tend\tstrand\tcontig_rank\n')
            for organism, records in sorted(all_records.items()):
                # Deduplicate gene IDs (keep first occurrence)
                seen: Dict[str, bool] = {}
                deduped = []
                for rec in records:
                    gid = rec[0]
                    if gid not in seen:
                        seen[gid] = True
                        deduped.append(rec)

                # Group by contig and assign per-contig rank sorted by start
                by_contig: Dict[str, List[Tuple[str, int, int, str]]] = defaultdict(list)
                for gene_id, contig, start, end, strand in deduped:
                    by_contig[contig].append((gene_id, start, end, strand))

                for contig, genes in sorted(by_contig.items()):
                    genes_sorted = sorted(genes, key=lambda x: x[1])  # sort by start
                    for rank, (gene_id, start, end, strand) in enumerate(genes_sorted):
                        coords_fh.write(
                            f'{organism}\t{gene_id}\t{contig}\t{start}\t{end}\t{strand}\t{rank}\n'
                        )
                        total_genes += 1

        print(f"[build_index] Wrote {total_genes} gene coordinate rows → {coords_out}", file=sys.stderr)
    else:
        print(f"[build_index] coords-out exists, skipping coordinate write", file=sys.stderr)

    # ── Write combined FAA with namespaced headers ─────────────────────────────
    # Header format: ><organism>@@<original_gene_id> [rest of description]
    total_seqs = 0
    with open(faa_out, 'w') as faa_fh:
        for organism in sorted(all_records.keys()):
            org_dir = rasttk_dir / organism
            faa_path = org_dir / 'gene_calls' / f'{organism}.faa'
            if not faa_path.exists():
                print(f"[build_index] WARNING: FAA not found: {faa_path}", file=sys.stderr)
                continue
            for header, seq in iter_faa(faa_path):
                if not seq:
                    continue
                # Extract original gene_id (first word) and rest of description
                parts = header.split(' ', 1)
                orig_gene_id = parts[0]
                description  = parts[1] if len(parts) > 1 else ''
                # Namespace: organism@@gene_id description
                new_header = f'{organism}@@{orig_gene_id}'
                if description:
                    new_header += f' {description}'
                faa_fh.write(f'>{new_header}\n{seq}\n')
                total_seqs += 1

    print(f"[build_index] Wrote {total_seqs} sequences → {faa_out}", file=sys.stderr)


if __name__ == '__main__':
    main()
