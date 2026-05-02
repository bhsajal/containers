#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# CONTAINER ENTRYPOINT — COG (COGclassifier v2)
# Placed at /usr/local/bin/run inside the container.
# Invoked automatically by:  apptainer run cog.sif [OPTIONS]
# ═══════════════════════════════════════════════════════════════════════════════

# ── SECTION 1: HELP ───────────────────────────────────────────────────────────
usage() {
    cat <<'HELP_EOF'

COG Functional Annotation Container — COGclassifier v2
───────────────────────────────────────────────────────

USAGE
  apptainer run \
    --bind <root>/db/cog:/db \
    --bind <path/to/organism.faa>:/input/organism.faa \
    --bind <path/to/output/dir>:/output \
    cog.sif \
    -i /input/organism.faa -o /output -d /db [OPTIONS]

REQUIRED MOUNTS
  --bind <root>/db/cog:/db
      COG database directory. Must contain cddid.tbl and Cog_LE/ (from
      03-db-setup.sh).

  --bind <path/to/organism.faa>:/input/organism.faa
      Protein FASTA file (.faa) produced by the gene caller (RAST-TK or
      Prodigal). The filename inside the container must match the -i argument.

  --bind <path/to/output/dir>:/output
      Output directory on the host. Must exist before running.
      Create it with:  mkdir -p <path/to/output/dir>

REQUIRED OPTIONS
  -i FILE     Path to protein FASTA input file  (inside container: /input/organism.faa)
  -o DIR      Path to output directory          (inside container: /output)
  -d DIR      Path to COG database directory    (inside container: /db)

OPTIONAL OPTIONS
  -t INT      Number of CPU threads             [default: 1]
  -e FLOAT    E-value cutoff for RPS-BLAST      [default: 0.01]
  --help      Show this help message and exit

EXAMPLE
  apptainer run \
    --bind /data/db/cog:/db \
    --bind /data/output/rasttk/myorg/gene_caller/myorg.faa:/input/myorg.faa \
    --bind /data/output/cog/myorg/native:/output \
    cog.sif \
    -i /input/myorg.faa -o /output -d /db -t 8 -e 0.01

OUTPUT FILES  (written to the bound /output directory)
  rpsblast.tsv                  Raw RPS-BLAST tabular results
  cog_classify.tsv              Per-protein COG annotation (9 columns)
  cog_count.tsv                 Protein count per functional category
  cog_count_barchart.png/.html  Bar chart of category distribution
  cog_count_piechart.png/.html  Pie chart of category proportions
  cogclassifier.log             Full run log

DATABASE SETUP
  See 03-db-setup.sh. Run once before the first execution.
  Expected database location (host): <root>/db/cog/

HELP_EOF
}

# ── SECTION 2: ARGUMENT DISPATCH ─────────────────────────────────────────────
if [[ $# -eq 0 || "$1" == "--help" || "$1" == "-h" ]]; then
    usage
    exit 0
fi

exec COGclassifier "$@"
