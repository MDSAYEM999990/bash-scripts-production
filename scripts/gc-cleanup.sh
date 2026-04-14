#!/bin/bash
# gc-cleanup.sh — Aggressively clean and compact a git repository.
# Usage: ./gc-cleanup.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

REPO_DIR="${1:-.}"
EXPIRY_DAYS=30

usage() {
    cat <<EOF
Usage: $(basename "$0") [repo-dir] [options]

Run git garbage collection, repack, prune, and reflog expiry on a repository.

Arguments:
  repo-dir          Path to the git repository (default: current directory)

Options:
  --expiry DAYS     Reflog expiry in days (default: ${EXPIRY_DAYS})
  -h, --help        Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") /opt/myrepo --expiry 14
EOF
    exit 0
}

args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --expiry)  EXPIRY_DAYS="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) args+=("$1"); shift ;;
    esac
done
[[ ${#args[@]} -ge 1 ]] && REPO_DIR="${args[0]}"

check_dependency git

cd "$REPO_DIR"

if ! git rev-parse --git-dir &>/dev/null; then
    log_error "Not a git repository: ${REPO_DIR}"
    exit 1
fi

log_info "Running git gc --prune=now..."
git gc --prune=now

log_info "Running git repack (deep compression)..."
git repack -a -d -f --depth=250 --window=250

log_info "Running git prune (unreferenced objects)..."
git prune

log_info "Expiring reflog entries older than ${EXPIRY_DAYS} days..."
git reflog expire --expire="${EXPIRY_DAYS}.days" --all

log_info "Running git fsck (integrity check)..."
git fsck --full --unreachable --verbose

log_info "Running git gc --aggressive..."
git gc --aggressive

log_info "Repository cleanup complete."
