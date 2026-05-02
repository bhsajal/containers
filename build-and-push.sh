#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# build-and-push.sh — Build all margie-annotation containers and push to GHCR
#
# Targets: ghcr.io/sajalbhattarai/<tool>:latest
#
# Multi-platform strategy:
#   • Most containers → linux/amd64,linux/arm64  (HPC + Mac native)
#   • Containers with FROM --platform=linux/amd64 hardcoded → linux/amd64 only
#     (interpro, aai, ani, synteny — depend on x86-only binaries)
#
# Requirements:
#   docker buildx  (Docker Desktop includes this)
#   GHCR login:
#     echo "$GITHUB_TOKEN" | docker login ghcr.io -u YOUR_GITHUB_USER --password-stdin
#
# Usage:
#   ./build-and-push.sh              # build + push all containers
#   ./build-and-push.sh cog pfam     # build + push specific containers only
#   PUSH=0 ./build-and-push.sh       # build locally without pushing (amd64 only)
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

REGISTRY="ghcr.io/sajalbhattarai"
PUSH="${PUSH:-1}"       # set PUSH=0 to build without pushing (skips --push)
CACHE="${CACHE:-1}"     # set CACHE=0 to disable layer cache

# Resolve the directory that contains this script (= processing/containers/ root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Container categories ──────────────────────────────────────────────────────
# AMD64-only: Dockerfile hard-pins FROM --platform=linux/amd64
AMD64_ONLY=(aai ani interpro synteny)

# Multi-arch: base images natively support linux/amd64 and linux/arm64
MULTI_ARCH=(cog dbcan eggnog geneprop kegg merops operon pfam pgap prodigal
            rasttk scoring tcdb tigrfam uniprot)

ALL_TOOLS=("${AMD64_ONLY[@]}" "${MULTI_ARCH[@]}")

# ── Argument: optional list of tools to build ─────────────────────────────────
TARGET_TOOLS=()
if [[ $# -gt 0 ]]; then
    TARGET_TOOLS=("$@")
else
    TARGET_TOOLS=("${ALL_TOOLS[@]}")
fi

# ── Ensure buildx builder is set up ──────────────────────────────────────────
# desktop-linux builder (Docker Desktop) supports multi-arch natively.
# On CI/Linux, create a dedicated multi-arch builder if needed.
if ! docker buildx inspect margie-builder &>/dev/null; then
    echo "[buildx] Creating multi-arch builder: margie-builder"
    docker buildx create --name margie-builder --driver docker-container \
        --platform linux/amd64,linux/arm64 --use
    docker buildx inspect --bootstrap margie-builder
else
    docker buildx use margie-builder
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
is_amd64_only() {
    local tool="$1"
    for t in "${AMD64_ONLY[@]}"; do [[ "$t" == "$tool" ]] && return 0; done
    return 1
}

build_container() {
    local tool="$1"
    local ctx="$SCRIPT_DIR/$tool"

    if [[ ! -d "$ctx" ]]; then
        echo "[skip] $tool — directory not found: $ctx"
        return 0
    fi

    local tag="$REGISTRY/$tool:latest"
    local platforms cache_flag=""

    if is_amd64_only "$tool"; then
        platforms="linux/amd64"
    else
        platforms="linux/amd64,linux/arm64"
    fi

    [[ "$CACHE" -eq 0 ]] && cache_flag="--no-cache"

    echo ""
    echo "══════════════════════════════════════════════════════"
    echo "  Building: $tool"
    echo "  Tag     : $tag"
    echo "  Platforms: $platforms"
    echo "══════════════════════════════════════════════════════"

    local push_flag="--load"   # default: load into local Docker daemon (amd64 only)
    if [[ "$PUSH" -eq 1 ]]; then
        push_flag="--push"     # push multi-arch manifest to registry
    fi

    docker buildx build \
        --platform "$platforms" \
        $push_flag \
        $cache_flag \
        --label "org.opencontainers.image.source=https://github.com/sajalbhattarai/containers" \
        --label "org.opencontainers.image.vendor=margie-annotation" \
        -t "$tag" \
        "$ctx"
}

# ── Build loop ────────────────────────────────────────────────────────────────
FAILED=()
for tool in "${TARGET_TOOLS[@]}"; do
    if build_container "$tool"; then
        echo "[ok] $tool"
    else
        echo "[FAIL] $tool"
        FAILED+=("$tool")
    fi
done

echo ""
echo "══════════════════════════════════════════════════════"
echo "  Build summary"
echo "══════════════════════════════════════════════════════"
built=$(( ${#TARGET_TOOLS[@]} - ${#FAILED[@]} ))
echo "  Built : $built / ${#TARGET_TOOLS[@]}"
if [[ "${#FAILED[@]}" -gt 0 ]]; then
    echo "  Failed: ${FAILED[*]}"
    exit 1
fi
[[ "$PUSH" -eq 1 ]] && echo "  Pushed to: $REGISTRY"
echo "  Done."
