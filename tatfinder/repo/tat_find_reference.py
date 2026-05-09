#!/usr/bin/env python3
"""
tat_find_reference.py  —  TatFind 1.4 algorithm, Python reference implementation
==================================================================================
FOR RECORDS ONLY.  The pipeline uses tat_find.pl (Perl version).
Both implement exactly the same algorithm.

CITATION
--------
Rose RW, Brüser T, Kissinger JC, Pohlschröder M (2002).
Adaptation of protein secretion to extremely high-salt conditions by
extensive use of the twin-arginine translocation pathway.
Molecular Microbiology 45(4):943–950.
https://doi.org/10.1046/j.1365-2958.2002.03090.x

USAGE
-----
    python3 tat_find_reference.py proteins.faa > results.tsv
    python3 tat_find_reference.py proteins.faa --strict > results.tsv

OPTIONS
-------
    --strict    Only report strong RR motifs. By default both RR (strong) and
                KR (weaker) are reported.
"""

# ============================================================
# BACKGROUND: What is a FASTA file of protein sequences?
# ============================================================
#
# A .faa file (FASTA Amino Acids) holds one or more protein sequences.
# Each protein starts with a header line that begins with ">" followed by
# a unique identifier and optional description, then on the next lines
# the amino acid sequence written using the standard 1-letter code:
#
#   A = Alanine      C = Cysteine    D = Aspartate   E = Glutamate
#   F = Phenylalanine G = Glycine    H = Histidine   I = Isoleucine
#   K = Lysine       L = Leucine     M = Methionine  N = Asparagine
#   P = Proline      Q = Glutamine   R = Arginine    S = Serine
#   T = Threonine    V = Valine      W = Tryptophan  Y = Tyrosine
#   * = Stop codon (ignored)
#
# Example entry:
#   >fig|6666666.1491171.peg.1  Hypothetical protein
#   MSTYSYKNPKFINSPKGVVEVVEVIYDGKDDPAYS...
#
# Proteins predicted from prokaryote genomes (e.g. via RASTtk) are stored
# this way.  Each protein has an ID like "fig|<genome>.<locus_tag>.peg.<num>":
#   fig  = PATRIC/RAST Figure identifier
#   peg  = Protein Encoding Gene (distinguishes from RNA genes, etc.)
#   num  = sequential number in the genome annotation

# ============================================================
# BACKGROUND: What are we trying to find?
# ============================================================
#
# Bacteria export (secrete) proteins through their cell membrane to the
# outside, or embed them into the membrane.  Two main pathways do this:
#
#   Sec pathway   — exports proteins while they are still UNFOLDED
#   Tat pathway   — exports proteins that are already FOLDED (pre-assembled)
#
# The Tat (Twin-Arginine Translocation) pathway is used for proteins that
# need to fold first — for example, proteins that require co-factors (like
# metal clusters) that must be loaded BEFORE export.
#
# How does the cell know which proteins go via which pathway?
# ─────────────────────────────────────────────────────────
# Every exported protein has a "signal peptide" at its N-terminus (beginning
# of the amino acid sequence).  The signal peptide is a short stretch (~15–40
# amino acids) that acts like a postal address label.  After export, the
# signal peptide is cleaved off by a signal peptidase.
#
# A Tat signal peptide has a distinctive pattern:
#
#   [n-region] — positively charged, ~1–15 aa
#   [RR-motif] — the conserved twin-arginine signature  ← THIS IS WHAT WE FIND
#   [h-region] — hydrophobic stretch, ~10–15 aa
#   [c-region] — signal peptidase cleavage site, ~5 aa
#
# The twin-arginine motif (RR) is almost invariably conserved.  TatFind 1.4
# scans the N-terminal 35 amino acids for this motif.

# ============================================================
# BACKGROUND: The TatFind 1.4 motif
# ============================================================
#
# The minimal consensus motif (Rose et al. 2002) is:
#
#   [LIVMF] [LIVMF] R R [^DE] [LIVMF]
#    ─┬───   ─┬───  │ │  ─┬─   ─┬───
#     │       │     │ │   │     └─ hydrophobic (Leu/Ile/Val/Met/Phe)
#     │       │     │ │   └─────── anything EXCEPT Asp(D) or Glu(E)
#     │       │     │ └─────────── Arginine (the second R, critical)
#     │       │     └───────────── Arginine (the first R, critical)
#     │       └─────────────────── hydrophobic (pre-RR h-region seed)
#     └─────────────────────────── hydrophobic (pre-RR h-region seed)
#
# The [^DE] position is important: a negatively charged residue (D or E)
# immediately after the RR pair drastically reduces Tat recognition.
#
# A weaker variant replaces the first R with K (Lysine, also positively
# charged but less specific):
#
#   [LIVMF] [LIVMF] K R [^DE] [LIVMF]   ← yes_KR
#
# CONCRETE EXAMPLE of a Tat signal in practice:
#
#   Protein sequence N-terminus (first 35 aa):
#   M  S  N  R  R  Q  F  L  K  Q  A  A  L  L  A  G  L  G  L  L  ...
#   1  2  3  4  5  6  7  8  9  10 ...
#
#   Here positions 3–8 match: S N  [LIVMF?]... actually let's use a textbook:
#
#   M  I  S  R  R  N  F  L ...
#            └──┘         └─ starts h-region
#            RR at positions 4-5
#   But we need [LIVMF] before RR:
#   e.g.  ...I  I  R  R  A  L...
#              └──┘
#              positions 2-3 are both Ile (I = hydrophobic)
#              positions 4-5 are RR (twin arginines)
#              position  6 is Ala (A ≠ D or E, so OK)
#              position  7 is Leu (L = hydrophobic)
#              → MATCH: motif = IIRRАЛ → tat_signal = yes_RR

import re
import sys
from typing import Iterator, Tuple

# ============================================================
# CONSTANTS
# ============================================================

# Only scan the first TAT_WINDOW amino acids of each protein.
# Tat signal peptides always start at the very N-terminus and are
# typically 15–40 aa long.  Rose et al. use 35 aa as the scan window.
TAT_WINDOW = 35

# ── Strong motif: twin ARGININE (RR) ──────────────────────────────────
# Regex character class meanings:
#   [LIVMF]  = any of: L (Leucine), I (Isoleucine), V (Valine),
#                      M (Methionine), F (Phenylalanine)
#              → all hydrophobic, non-polar amino acids
#   R        = Arginine (positively charged, fixed)
#   [^DE]    = anything except D (Aspartate) or E (Glutamate)
#              → excludes negatively charged residues at this position
#
# Together: two hydrophobics, two arginines, one non-acidic, one hydrophobic
MOTIF_RR = re.compile(r'([LIVMF][LIVMF]RR[^DE][LIVMF])')

# ── Weaker motif: LYSINE-ARGININE (KR) ───────────────────────────────
# Same pattern but the first Arginine is replaced by K (Lysine).
# Lysine is also positively charged but the Tat machinery recognises it
# less efficiently.  These proteins may still be exported via Tat but
# with lower efficiency.
MOTIF_KR = re.compile(r'([LIVMF][LIVMF]KR[^DE][LIVMF])')

# ============================================================
# STEP 1: Parse the FASTA file
# ============================================================
#
# We read the .faa file and yield one (protein_id, sequence) pair at a time.
# This is a "generator" — it reads one protein into memory at a time rather
# than loading the entire file at once (important for large genomes).
#
# The FASTA format looks like:
#   >protein_id optional description here
#   MSTYSYKNPKFINSPKGVVEVVEVIYDGKDDPAYS
#   VQGIDNDPFDNPQRKLQEGKEFNVDDYAPKKGDQS   ← sequence can span multiple lines
#   ...
#   >next_protein_id
#   MKLPVAAAVLALLSGCQASHAPLNGEQISKAVSQNM
#   ...

def parse_fasta(filepath: str) -> Iterator[Tuple[str, str]]:
    """
    Read a FASTA amino acid file and yield (protein_id, sequence) tuples.

    protein_id  : first "word" of the header line (everything up to the first
                  whitespace), with the leading ">" stripped.
                  Example: "fig|6666666.1491171.peg.4930"

    sequence    : full amino acid sequence, uppercase, whitespace removed,
                  stop codons (*) removed.
                  Example: "MSTYSYKNPKFINSPKGVVEVVEVIYDGKDDPAYS"
    """
    protein_id = None
    seq_parts  = []

    with open(filepath) as fh:
        for line in fh:
            line = line.rstrip('\n')

            if line.startswith('>'):
                # ── New record: yield the previous one (if any) ──────
                if protein_id is not None:
                    yield protein_id, ''.join(seq_parts).upper().replace('*', '')
                # ── Parse the new header ─────────────────────────────
                # Header example: ">fig|6666666.1491171.peg.1  DNA-binding protein"
                # We only want the ID part (first token after ">")
                protein_id = line[1:].split()[0]
                seq_parts  = []

            else:
                # ── Sequence line: accumulate ─────────────────────────
                seq_parts.append(line.strip())

    # ── Yield the last record (file doesn't end with a new ">") ─────
    if protein_id is not None:
        yield protein_id, ''.join(seq_parts).upper().replace('*', '')


# ============================================================
# STEP 2: Scan the N-terminal window for the motif
# ============================================================
#
# For each protein we:
#   a) Take only the first TAT_WINDOW (35) amino acids
#   b) Search for MOTIF_RR first (strong signal)
#   c) If not found, optionally search for MOTIF_KR (weaker signal)
#   d) Record the result

def scan_protein(protein_id: str, seq: str, strict: bool = False) -> dict:
    """
    Scan one protein sequence for a Tat signal peptide motif.

    Parameters
    ----------
    protein_id : str
        Unique protein identifier from the FASTA header.
    seq : str
        Full amino acid sequence (uppercase).
    strict : bool
        If True, only report RR hits (ignore KR).

    Returns
    -------
    dict with keys:
        protein_id   – identifier
        tat_signal   – "yes_RR", "yes_KR", or "no"
        motif_start  – 1-based start position within the 35-aa window,
                       or "." if no hit
        motif        – the 6-aa matched string, or "."
        window_seq   – the first 35 aa examined (or full sequence if shorter)

    Example output for a positive hit:
        {
          "protein_id":  "fig|6666666.1491171.peg.123",
          "tat_signal":  "yes_RR",
          "motif_start": 9,
          "motif":       "LLRRAL",
          "window_seq":  "MSSAAVQGLLRRALAAAGLAGVLA..."
        }

    Example output for a negative result:
        {
          "protein_id":  "fig|6666666.1491171.peg.456",
          "tat_signal":  "no",
          "motif_start": ".",
          "motif":       ".",
          "window_seq":  "MEQGEIILYQPDEAVKLEVRLEDET..."
        }
    """

    # ── a) Restrict to N-terminal window ─────────────────────────────
    # Tat signal peptides only occur at the very beginning of the protein.
    # Scanning only 35 aa avoids false positives in the protein body and
    # is much faster on large proteomes.
    window = seq[:TAT_WINDOW]
    #
    # Example:
    #   Full seq  : MSSAAVQGLLRRALAAAGLAGVLAGAAPAAHAQPADAH...  (4930 aa)
    #   window    : MSSAAVQGLLRRALAAAGLAGVLAGAAPAAHAQPADA     (first 35 aa)
    #                         ^^^^^^ ← motif region of interest

    # ── b) Search for strong RR motif ────────────────────────────────
    m = MOTIF_RR.search(window)
    if m:
        return {
            "protein_id":  protein_id,
            "tat_signal":  "yes_RR",
            # m.start() is 0-based; add 1 for 1-based (biological convention)
            "motif_start": m.start() + 1,
            "motif":       m.group(1),   # the 6-aa matched substring
            "window_seq":  window
        }
        # Example match:
        #   window    : "MSSAAVQGLLRRALAAAGLAGV..."
        #   m.group(1): "LLRRAL"   (matches [LIVMF][LIVMF]RR[^DE][LIVMF])
        #   m.start() : 9  → motif_start = 10 (1-based)
        #   L = Leu  ✓ hydrophobic
        #   L = Leu  ✓ hydrophobic
        #   R = Arg  ✓ first arginine
        #   R = Arg  ✓ second arginine (the "twin")
        #   A = Ala  ✓ not D or E
        #   L = Leu  ✓ hydrophobic

    # ── c) Search for weaker KR motif (unless --strict) ──────────────
    if not strict:
        m = MOTIF_KR.search(window)
        if m:
            return {
                "protein_id":  protein_id,
                "tat_signal":  "yes_KR",
                "motif_start": m.start() + 1,
                "motif":       m.group(1),
                "window_seq":  window
            }
            # Example KR match:
            #   window    : "MTSAAVQGLLKRALAAAGLAG..."
            #   m.group(1): "LLKRAL"
            #   L = Leu  ✓ hydrophobic
            #   L = Leu  ✓ hydrophobic
            #   K = Lys  ✓ positively charged (weaker than R)
            #   R = Arg  ✓ arginine
            #   A = Ala  ✓ not D or E
            #   L = Leu  ✓ hydrophobic

    # ── d) No match ───────────────────────────────────────────────────
    return {
        "protein_id":  protein_id,
        "tat_signal":  "no",
        "motif_start": ".",   # "." is the TSV convention for "not applicable"
        "motif":       ".",
        "window_seq":  window
    }


# ============================================================
# STEP 3: Write TSV output
# ============================================================
#
# Tab-separated values (TSV) is a simple table format:
# each line is a row, columns are separated by tab characters (\t).
# The first row is a header naming the columns.
#
# Output columns:
#   protein_id       – unique ID from the FASTA header
#   tat_signal       – yes_RR / yes_KR / no
#   motif_start      – 1-based position of motif within the 35-aa window
#   motif            – the 6 matched amino acids (e.g. "LLRRAL")
#   window_seq       – first 35 aa of the protein (what was scanned)

def main():
    # ── Parse command-line arguments ──────────────────────────────────
    args   = sys.argv[1:]
    strict = '--strict' in args
    inputs = [a for a in args if not a.startswith('--')]

    if not inputs:
        print("Usage: python3 tat_find_reference.py <input.faa> [--strict]",
              file=sys.stderr)
        sys.exit(1)

    faa_path = inputs[0]

    # ── Write TSV header ───────────────────────────────────────────────
    columns = ["protein_id", "tat_signal", "motif_start", "motif", "window_seq"]
    print('\t'.join(columns))

    # ── Process each protein ───────────────────────────────────────────
    for protein_id, seq in parse_fasta(faa_path):
        result = scan_protein(protein_id, seq, strict=strict)
        print('\t'.join(str(result[c]) for c in columns))


if __name__ == '__main__':
    main()


# ============================================================
# SUMMARY: What this script produces and what the values mean
# ============================================================
#
# INPUT
#   A prokaryote proteome .faa file — typically from RASTtk annotation.
#   All predicted protein-coding sequences for one genome.
#   For Bacteroides thetaiotaomicron GCF_014131755.1 this is ~4930 proteins.
#
# OUTPUT columns
#   protein_id      Unique locus ID (e.g. fig|6666666.1491171.peg.123)
#                   "peg" = Protein Encoding Gene
#
#   tat_signal      yes_RR  → Strong Tat signal — likely exported via Tat
#                   yes_KR  → Weaker Tat signal — possibly exported via Tat
#                   no      → No Tat motif found in N-terminal 35 aa
#
#   motif_start     1-based position where the 6-aa motif begins in the
#                   35-aa window.  "." if tat_signal = "no".
#                   Example: 9 means the motif starts at residue 9.
#
#   motif           The exact 6 amino acids matched, e.g. "LLRRAL".
#                   "." if tat_signal = "no".
#
#   window_seq      The first 35 amino acids that were searched.
#                   Useful for manual inspection or downstream filtering.
#
# WHAT TO DO WITH THE RESULTS
#   Proteins with tat_signal = yes_RR are strong candidates for Tat-exported
#   proteins.  In Bacteroides thetaiotaomicron, about 36 out of ~4930 proteins
#   (~0.7%) carry a Tat signal.  These are typically:
#     - Cofactor-containing enzymes (e.g. [Fe-S] cluster proteins)
#     - Periplasmic binding proteins
#     - Cell-surface or outer membrane proteins that fold in the cytoplasm
#   The results can be cross-referenced with PSORTb localization predictions
#   (which also uses Tat signal detection) and with TMbed/TMHMM to distinguish
#   Tat-exported soluble periplasmic proteins from membrane proteins.
