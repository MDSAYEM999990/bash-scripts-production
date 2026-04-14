#!/bin/bash
# git-cleanup-merged.sh — Delete merged branches locally and optionally on remote
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "${SCRIPT_DIR}/../lib/utils.sh"

REMOTE="origin"
BASE_BRANCH="main"
DRY_RUN=false
DELETE_REMOTE=false
PROTECTED="main master develop release"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Delete all local branches that have been merged into the base branch.
Optionally also deletes the remote tracking branches.

Options:
  --base BRANCH       Base branch to check merges against   (default: main)
  --remote NAME       Remote name                           (default: origin)
  --delete-remote     Also delete merged branches on the remote
  --dry-run           Show what would be deleted, make no changes
  -h, --help          Show this help message

Examples:
  $(basename "$0") --dry-run
  $(basename "$0") --base main --delete-remote
  $(basename "$0") --base develop --remote upstream
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --base)          BASE_BRANCH="$2"; shift 2 ;;
        --remote)        REMOTE="$2";       shift 2 ;;
        --delete-remote) DELETE_REMOTE=true; shift ;;
        --dry-run)       DRY_RUN=true;      shift ;;
        -h|--help)       usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

check_dependency git

# Ensure we are inside a git repository
git rev-parse --is-inside-work-tree &>/dev/null || {
    log_error "Not inside a Git repository."
    exit 2
}

# Fetch to get up-to-date merge info
log_info "Fetching '${REMOTE}'..."
git fetch "$REMOTE" --prune 2>/dev/null || log_warn "git fetch failed — working with local state only."

# Collect merged branches, excluding protected names
MERGED_BRANCHES=$(git branch --merged "$BASE_BRANCH" | grep -v '\*' | tr -d ' ' | grep -Ev "^(${PROTECTED// /|})$") || true

if [[ -z "$MERGED_BRANCHES" ]]; then
    log_info "No merged branches to clean up."
    exit 0
fi

DELETED=0
while IFS= read -r branch; do
    [[ -z "$branch" ]] && continue
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[dry-run] Would delete local branch: ${branch}"
    else
        log_info "Deleting local branch: ${branch}"
        git branch -d "$branch"
        (( DELETED++ )) || true
    fi

    if [[ "$DELETE_REMOTE" == "true" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[dry-run] Would delete remote branch: ${REMOTE}/${branch}"
        else
            log_info "Deleting remote branch: ${REMOTE}/${branch}"
            git push "$REMOTE" --delete "$branch" 2>/dev/null || log_warn "Remote branch '${branch}' not found — skipping."
        fi
    fi
done <<< "$MERGED_BRANCHES"

if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[dry-run] No changes made."
else
    log_info "Deleted ${DELETED} merged branch(es)."
fi
exit 0
