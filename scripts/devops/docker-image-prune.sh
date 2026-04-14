#!/bin/bash
# docker-image-prune.sh — Remove dangling and/or aged Docker images
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "${SCRIPT_DIR}/../lib/utils.sh"

OLDER_THAN=""
FILTER_LABEL=""
DRY_RUN=false
ALL_UNUSED=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Remove dangling Docker images (not tagged, not referenced by a container).
Optionally also remove unused images older than a given duration.

Options:
  --older-than DURATION   Remove unused images older than this     (e.g. 72h, 30d)
  --label KEY=VALUE       Only remove images matching this label
  --all-unused            Remove ALL unused images (not just dangling)
  --dry-run               Show what would be removed, make no changes
  -h, --help              Show this help message

Examples:
  $(basename "$0") --dry-run
  $(basename "$0") --older-than 72h
  $(basename "$0") --all-unused --older-than 30d
  $(basename "$0") --label env=staging --dry-run
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --older-than)  OLDER_THAN="$2";    shift 2 ;;
        --label)       FILTER_LABEL="$2";  shift 2 ;;
        --all-unused)  ALL_UNUSED=true;    shift ;;
        --dry-run)     DRY_RUN=true;       shift ;;
        -h|--help)     usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

check_dependency docker

# Build filter args
FILTERS=()
if [[ "$ALL_UNUSED" == "true" ]]; then
    FILTERS+=(--filter "dangling=false")
else
    FILTERS+=(--filter "dangling=true")
fi
[[ -n "$OLDER_THAN" ]]    && FILTERS+=(--filter "until=${OLDER_THAN}")
[[ -n "$FILTER_LABEL" ]]  && FILTERS+=(--filter "label=${FILTER_LABEL}")

log_info "Listing images to remove..."
IMAGES=$(docker images -q "${FILTERS[@]}" 2>/dev/null | sort -u) || true

if [[ -z "$IMAGES" ]]; then
    log_info "No images match the removal criteria."
    exit 0
fi

IMAGE_COUNT=$(echo "$IMAGES" | wc -l | tr -d ' ')

if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[dry-run] Would remove ${IMAGE_COUNT} image(s):"
    # Show human-readable info for each image
    while IFS= read -r img_id; do
        docker image inspect --format "  {{.ID}} {{.RepoTags}}" "$img_id" 2>/dev/null || echo "  ${img_id}"
    done <<< "$IMAGES"
    exit 0
fi

log_info "Removing ${IMAGE_COUNT} image(s)..."
while IFS= read -r img_id; do
    docker rmi "$img_id" && log_info "Removed: ${img_id}" || log_warn "Could not remove: ${img_id}"
done <<< "$IMAGES"

log_info "Docker image prune complete."
exit 0
