#!/bin/bash
# restart-containers.sh — Restart all running Docker containers, or a named set.
# Usage: ./restart-containers.sh [options] [container ...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

DRY_RUN=false
CONTAINERS=()

usage() {
    cat <<EOF
Usage: $(basename "$0") [options] [container ...]

Restart Docker containers. With no arguments, restarts all currently-running containers.

Options:
  --dry-run    Print what would be restarted; make no changes
  -h, --help   Show this help message

Examples:
  $(basename "$0") --dry-run
  $(basename "$0") nginx redis
  $(basename "$0")
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) usage ;;
        *)         CONTAINERS+=("$1"); shift ;;
    esac
done

check_dependency docker

if [[ ${#CONTAINERS[@]} -eq 0 ]]; then
    # while-read loop replaces mapfile (compatible with bash 3.2 on macOS)
    while IFS= read -r c; do
        CONTAINERS+=("$c")
    done < <(docker ps --format '{{.Names}}')
fi

if [[ ${#CONTAINERS[@]} -eq 0 ]]; then
    log_info "No running containers found."
    exit 0
fi

log_info "Containers to restart: ${CONTAINERS[*]}"

if "$DRY_RUN"; then
    for c in "${CONTAINERS[@]}"; do
        log_warn "[DRY RUN] Would restart: ${c}"
    done
    exit 0
fi

for c in "${CONTAINERS[@]}"; do
    log_info "Restarting container '${c}'..."
    docker restart "$c"
    log_info "Container '${c}' restarted."
done

log_info "All done."
