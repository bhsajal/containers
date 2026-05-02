#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# CONTAINER ENTRYPOINT — Synteny (DIAMOND protein comparison)
# Placed at /container/scripts/entrypoint.sh inside the container.
# Invoked by: docker run ... annotation/synteny:latest [OPTIONS]
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────
RASTTK_DIR="/input"
OUTPUT_DIR="/output"
ORGANISM=""
PARTNERS=""
THREADS=4
MIN_IDENTITY=30
MIN_COVERAGE=50
DB_SCOPE="partners"   # partners = per-organism DB (query+partners only)
                      # all      = shared DB from all organisms in /input
BUILD_DB_ONLY=0

# ── Help ─────────────────────────────────────────────────────────────────────
usage() {
    cat <<'HELP_EOF'

Synteny Analysis Container — DIAMOND protein comparison
────────────────────────────────────────────────────────

USAGE
  docker run --rm \
    -v <rasttk_dir>:/input:ro \
    -v <synteny_native_dir>:/output:rw \
    annotation/synteny:latest \
    --organism <name> --partners <A,B,C,D,E> [OPTIONS]

REQUIRED MOUNTS
  /input    RASTtk output root. Expected layout:
              /input/<organism>/gene_calls/<organism>.faa
              /input/<organism>/gene_calls/<organism>.gff
  /output   Native output directory.

REQUIRED OPTIONS
  --organism NAME       Organism identifier to run DIAMOND query for

OPTIONAL OPTIONS
  --partners A,B,C      Comma-separated partner organism names for synteny
                        block detection. Required unless --build-db-only.
  --db-scope MODE       'partners' (default) — build a tiny per-organism DB
                            from query + partners only. Fast, low memory.
                        'all' — build/reuse one shared DB from all /input
                            organisms. Slower to build once, reused after.
  --threads N           CPU threads (default: 4)
  --min-identity N      Minimum % identity filter (default: 30)
  --min-coverage N      Minimum query coverage % filter (default: 50)
  --build-db-only       (only with --db-scope all) Build shared DB, no query.
  --help                Show this message

OUTPUT FILES (--db-scope partners)
  <organism>/db/          Per-organism DIAMOND database
  <organism>/gene_coords.tsv
  <organism>/diamond_hits.tsv
  <organism>/synteny_blocks.tsv

OUTPUT FILES (--db-scope all)
  db/                   Shared DIAMOND database (reused across organisms)
  gene_coords.tsv       Shared coordinate index
  <organism>/diamond_hits.tsv
  <organism>/synteny_blocks.tsv

HELP_EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────
if [[ $# -eq 0 || "$1" == "--help" || "$1" == "-h" ]]; then
    usage; exit 0
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --organism)       ORGANISM="$2";       shift 2 ;;
        --partners)       PARTNERS="$2";       shift 2 ;;
        --db-scope)       DB_SCOPE="$2";       shift 2 ;;
        --threads)        THREADS="$2";        shift 2 ;;
        --min-identity)   MIN_IDENTITY="$2";   shift 2 ;;
        --min-coverage)   MIN_COVERAGE="$2";   shift 2 ;;
        --build-db-only)  BUILD_DB_ONLY=1;     shift   ;;
        --help|-h)        usage; exit 0 ;;
        *) echo "[synteny] ERROR: Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ "$DB_SCOPE" != "partners" && "$DB_SCOPE" != "all" ]]; then
    echo "[synteny] ERROR: --db-scope must be 'partners' or 'all'" >&2; exit 1
fi
if [[ $BUILD_DB_ONLY -eq 0 && -z "$ORGANISM" ]]; then
    echo "[synteny] ERROR: --organism is required" >&2; exit 1
fi
# --partners is required for db-scope=partners, optional for db-scope=all
if [[ "$DB_SCOPE" == "partners" && $BUILD_DB_ONLY -eq 0 && -z "$PARTNERS" ]]; then
    echo "[synteny] ERROR: --partners is required when --db-scope partners" >&2; exit 1
fi

# ── Provenance helper ────────────────────────────────────────────────────────
# Writes a machine-readable key=value file: native/run_info.txt
# The host process.py reads this to build the single authoritative pipeline.txt.
write_run_info() {
    local org_out="$1"    # directory to write run_info.txt into (native/)
    local db_scope="$2"
    local org="$3"
    local partners="$4"
    local hits_out="$5"
    local diamond_ver
    diamond_ver=$(diamond version 2>&1 | head -1 | tr -d '\n' || echo "unknown")
    local n_hits=0
    [[ -f "$hits_out" ]] && n_hits=$(wc -l < "$hits_out" | tr -d ' ')

    cat > "$org_out/run_info.txt" << EOF
organism=${org}
date=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
diamond_version=${diamond_ver}
db_scope=${db_scope}
partners=${partners}
min_identity=${MIN_IDENTITY}
min_coverage=${MIN_COVERAGE}
threads=${THREADS}
n_hits=${n_hits}
EOF
    echo "[synteny] Run info written: $org_out/run_info.txt"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MODE A: --db-scope partners  (default, recommended)
#   Build a tiny DB per organism: query + top-N partners only.
#   DB lives in $OUTPUT_DIR/$ORGANISM/db/ — no sharing between organisms.
# ═══════════════════════════════════════════════════════════════════════════════
if [[ "$DB_SCOPE" == "partners" ]]; then
    # Write all output to $OUTPUT_DIR/native/ so the host sees:
    #   output/synteny/<organism>/native/gene_coords.tsv
    #   output/synteny/<organism>/native/diamond_hits.tsv  etc.
    # (The caller mounts output/synteny/<organism> as /output.)
    ORG_OUT="$OUTPUT_DIR/native"
    DB_DIR="$ORG_OUT/db"
    COORDS_FILE="$ORG_OUT/gene_coords.tsv"
    HITS_OUT="$ORG_OUT/diamond_hits.tsv"

    mkdir -p "$DB_DIR"

    # Organisms for this DB: query + all partners
    DB_ORGANISMS="$ORGANISM,$PARTNERS"

    echo "[synteny] db-scope=partners  query=$ORGANISM"
    echo "[synteny]   DB organisms: $DB_ORGANISMS"

    # Build coords + FAA for query+partners only
    echo "[synteny] Building per-organism index (query + partners) ..."
    python3 /container/scripts/build_index.py \
        --rasttk-dir "$RASTTK_DIR" \
        --coords-out "$COORDS_FILE" \
        --faa-out    "$DB_DIR/proteins.faa" \
        --organisms  "$DB_ORGANISMS"

    # Build DIAMOND DB
    echo "[synteny] Building per-organism DIAMOND database ..."
    diamond makedb \
        --in      "$DB_DIR/proteins.faa" \
        --db      "$DB_DIR/proteins" \
        --threads "$THREADS" \
        --quiet
    echo "[synteny] DB ready: $DB_DIR/proteins.dmnd"

    # DIAMOND blastp
    QUERY_FAA="$RASTTK_DIR/$ORGANISM/gene_calls/$ORGANISM.faa"
    [[ ! -f "$QUERY_FAA" ]] && { echo "[synteny] ERROR: FAA not found: $QUERY_FAA" >&2; exit 1; }

    echo "[synteny] Running DIAMOND blastp ..."
    echo "[synteny]   identity>=${MIN_IDENTITY}%  coverage>=${MIN_COVERAGE}%  threads=${THREADS}"
    diamond blastp \
        --db           "$DB_DIR/proteins.dmnd" \
        --query        "$QUERY_FAA" \
        --out          "$HITS_OUT" \
        --outfmt 6 qseqid sseqid pident length qlen slen evalue bitscore \
        --threads      "$THREADS" \
        --more-sensitive \
        --id           "$MIN_IDENTITY" \
        --query-cover  "$MIN_COVERAGE" \
        --max-target-seqs 50 \
        --compress 0 \
        --quiet

    echo "[synteny] DIAMOND done: $(wc -l < "$HITS_OUT") hits → $HITS_OUT"

    # Synteny block detection
    echo "[synteny] Detecting synteny blocks vs partners: $PARTNERS"
    python3 /container/scripts/process_synteny.py \
        --diamond-hits "$HITS_OUT" \
        --coords       "$COORDS_FILE" \
        --organism     "$ORGANISM" \
        --partners     "$PARTNERS" \
        --out-dir      "$ORG_OUT"

    write_run_info "$ORG_OUT" "partners" "$ORGANISM" "$PARTNERS" "$HITS_OUT"
    echo "[synteny] Done: $ORGANISM"
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════════
# MODE B: --db-scope all
#   Build one shared DB from all organisms in /input.
#   DB lives in $OUTPUT_DIR/db/ — shared and reused across organism runs.
# ═══════════════════════════════════════════════════════════════════════════════
DB_DIR="$OUTPUT_DIR/db"
COORDS_FILE="$OUTPUT_DIR/gene_coords.tsv"

# Step 1: Build shared coordinate index + FAA (once)
if [[ ! -f "$COORDS_FILE" ]]; then
    echo "[synteny] db-scope=all  Building shared gene coordinate index ..."
    python3 /container/scripts/build_index.py \
        --rasttk-dir "$RASTTK_DIR" \
        --coords-out "$COORDS_FILE" \
        --faa-out    "$DB_DIR/all_proteins.faa"
    echo "[synteny] gene_coords.tsv written: $COORDS_FILE"
else
    echo "[synteny] gene_coords.tsv already exists — skipping"
fi

# Step 2: Build shared DIAMOND DB (once)
if [[ ! -f "$DB_DIR/all_proteins.dmnd" ]]; then
    echo "[synteny] Building shared DIAMOND database ..."
    mkdir -p "$DB_DIR"
    if [[ ! -f "$DB_DIR/all_proteins.faa" ]]; then
        python3 /container/scripts/build_index.py \
            --rasttk-dir "$RASTTK_DIR" \
            --coords-out "$COORDS_FILE" \
            --faa-out    "$DB_DIR/all_proteins.faa" \
            --coords-skip-if-exists
    fi
    diamond makedb \
        --in      "$DB_DIR/all_proteins.faa" \
        --db      "$DB_DIR/all_proteins" \
        --threads "$THREADS" \
        --quiet
    echo "[synteny] Shared DIAMOND database built: $DB_DIR/all_proteins.dmnd"
else
    echo "[synteny] Shared DIAMOND database already exists — skipping"
fi

[[ $BUILD_DB_ONLY -eq 1 ]] && { echo "[synteny] --build-db-only done"; exit 0; }

# Step 3: DIAMOND blastp for target organism
QUERY_FAA="$RASTTK_DIR/$ORGANISM/gene_calls/$ORGANISM.faa"
[[ ! -f "$QUERY_FAA" ]] && { echo "[synteny] ERROR: FAA not found: $QUERY_FAA" >&2; exit 1; }

ORG_OUT="$OUTPUT_DIR/$ORGANISM"
mkdir -p "$ORG_OUT"
HITS_OUT="$ORG_OUT/diamond_hits.tsv"

echo "[synteny] db-scope=all  Running DIAMOND blastp for: $ORGANISM"
echo "[synteny]   identity>=${MIN_IDENTITY}%  coverage>=${MIN_COVERAGE}%  threads=${THREADS}"

diamond blastp \
    --db           "$DB_DIR/all_proteins.dmnd" \
    --query        "$QUERY_FAA" \
    --out          "$HITS_OUT" \
    --outfmt 6 qseqid sseqid pident length qlen slen evalue bitscore \
    --threads      "$THREADS" \
    --more-sensitive \
    --id           "$MIN_IDENTITY" \
    --query-cover  "$MIN_COVERAGE" \
    --max-target-seqs 50 \
    --compress 0 \
    --quiet

echo "[synteny] DIAMOND done: $(wc -l < "$HITS_OUT") hits → $HITS_OUT"

# Step 4: Synteny block detection
if [[ -n "$PARTNERS" ]]; then
    echo "[synteny] Detecting synteny blocks vs partners: $PARTNERS"
    python3 /container/scripts/process_synteny.py \
        --diamond-hits "$HITS_OUT" \
        --coords       "$COORDS_FILE" \
        --organism     "$ORGANISM" \
        --partners     "$PARTNERS" \
        --out-dir      "$ORG_OUT"
else
    echo "[synteny] --partners not supplied — skipping synteny block detection"
fi

write_run_info "$ORG_OUT" "all" "$ORGANISM" "$PARTNERS" "$HITS_OUT"
echo "[synteny] Done: $ORGANISM"

