#!/usr/bin/env python3
"""
Convert RAST GFF3 + FAA to UniOP Prodigal-style FAA format.

UniOP expects FAA file with Prodigal-style headers containing gene metadata:
>contig_name_genenum # start # stop # strand # attribute

Where:
- contig_name_genenum: contig identifier with gene number suffix
- start: gene start position (int)
- stop: gene end position (int)
- strand: 1 (forward) or -1 (reverse)
- attribute: additional gene metadata

Input: RAST GFF3 file (theta.gff) and FAA file (theta.faa)
Output: Prodigal-style FAA file for UniOP input
"""

import sys
import re
from pathlib import Path
from collections import defaultdict


def parse_gff_attributes(attr_string):
    """
    Parse GFF3 attributes field to extract gene ID.
    
    Example: "ID=fig|6666666.1476522.peg.2429;Name=Putative alpha-glucosidase"
    Returns: "fig|6666666.1476522.peg.2429"
    """
    # Extract ID= field
    id_match = re.search(r'ID=([^;]+)', attr_string)
    if id_match:
        return id_match.group(1)
    return None


def parse_faa(faa_path):
    """
    Parse RAST FAA file to get sequences by gene ID.
    
    Returns: dict mapping gene_id -> sequence
    """
    sequences = {}
    current_id = None
    current_seq = []
    
    with open(faa_path, 'r') as f:
        for line in f:
            if line.startswith('>'):
                # Save previous sequence
                if current_id:
                    sequences[current_id] = ''.join(current_seq)
                
                # Parse new header
                # Format: >fig|6666666.1476522.peg.2429 Putative alpha-glucosidase [...]
                header = line[1:].strip()
                gene_id = header.split()[0]  # Get first token (the gene ID)
                current_id = gene_id
                current_seq = []
            else:
                current_seq.append(line.strip())
        
        # Save last sequence
        if current_id:
            sequences[current_id] = ''.join(current_seq)
    
    return sequences


def convert_gff_to_uniop_faa(gff_path, faa_path, output_path):
    """
    Convert RAST GFF3 + FAA to UniOP Prodigal-style FAA format.
    
    Args:
        gff_path: Path to input GFF3 file
        faa_path: Path to input FAA file
        output_path: Path to output Prodigal-style FAA file
    """
    # Parse FAA to get sequences
    print("Reading protein sequences from FAA file...")
    sequences = parse_faa(faa_path)
    print(f"Loaded {len(sequences)} protein sequences")
    
    # Parse GFF to get gene coordinates
    print("Reading gene coordinates from GFF file...")
    gene_records = []
    gene_counter = defaultdict(int)  # Count genes per contig
    
    with open(gff_path, 'r') as infile:
        for line in infile:
            # Skip header lines
            if line.startswith('#'):
                continue
            
            # Skip empty lines
            if not line.strip():
                continue
            
            # Parse GFF3 columns
            fields = line.strip().split('\t')
            if len(fields) < 9:
                continue
            
            seqid = fields[0]      # Column 1: sequence/contig ID
            feature_type = fields[2]  # Column 3: feature type
            start = fields[3]      # Column 4: start position
            end = fields[4]        # Column 5: end position
            strand = fields[6]     # Column 7: strand (+ or -)
            attributes = fields[8] # Column 9: attributes
            
            # Only process CDS features
            if feature_type != 'CDS':
                continue
            
            # Extract gene ID from attributes
            gene_id = parse_gff_attributes(attributes)
            if not gene_id:
                print(f"Warning: Could not extract gene ID from: {attributes}", file=sys.stderr)
                continue
            
            # Convert strand to numeric (1 or -1)
            strand_num = 1 if strand == '+' else -1
            
            # Increment gene counter for this contig
            gene_counter[seqid] += 1
            gene_num = gene_counter[seqid]
            
            # Store record
            gene_records.append({
                'nc': seqid,
                'gene_num': gene_num,
                'start': int(start),
                'stop': int(end),
                'strand': strand_num,
                'gene_id': gene_id,
                'sequence': sequences.get(gene_id, '')
            })
    
    # Sort by contig and start position to maintain gene order
    gene_records.sort(key=lambda x: (x['nc'], x['start']))
    
    print(f"Parsed {len(gene_records)} CDS features from GFF")
    
    # Write output in Prodigal-style format
    print("Writing Prodigal-style FAA file...")
    written_count = 0
    missing_seq_count = 0
    
    with open(output_path, 'w') as outfile:
        for record in gene_records:
            if not record['sequence']:
                missing_seq_count += 1
                print(f"Warning: No sequence found for gene {record['gene_id']}", file=sys.stderr)
                continue
            
            # Write Prodigal-style header
            # Format: >contig_name_genenum # start # stop # strand # ID=gene_id
            header = f">{record['nc']}_{record['gene_num']} # {record['start']} # {record['stop']} # {record['strand']} # ID={record['gene_id']}"
            outfile.write(f"{header}\n")
            
            # Write sequence (wrap at 60 chars per line)
            seq = record['sequence']
            for i in range(0, len(seq), 60):
                outfile.write(f"{seq[i:i+60]}\n")
            
            written_count += 1
    
    print(f"Successfully wrote {written_count} genes to {output_path}")
    if missing_seq_count > 0:
        print(f"Warning: {missing_seq_count} genes had no sequence data", file=sys.stderr)


def main():
    if len(sys.argv) != 4:
        print("Usage: convert_rast_to_uniop.py <input_gff> <input_faa> <output_faa>")
        print("Example: convert_rast_to_uniop.py theta.gff theta.faa theta_prodigal_style.faa")
        sys.exit(1)
    
    gff_path = Path(sys.argv[1])
    faa_path = Path(sys.argv[2])
    output_path = Path(sys.argv[3])
    
    if not gff_path.exists():
        print(f"Error: GFF file not found: {gff_path}", file=sys.stderr)
        sys.exit(1)
    
    if not faa_path.exists():
        print(f"Error: FAA file not found: {faa_path}", file=sys.stderr)
        sys.exit(1)
    
    # Create output directory if needed
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    convert_gff_to_uniop_faa(gff_path, faa_path, output_path)


if __name__ == '__main__':
    main()
