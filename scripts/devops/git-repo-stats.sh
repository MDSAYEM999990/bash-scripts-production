#!/bin/bash
# git-repo-stats.sh — Print useful statistics about a git repository.
# Usage: ./git-repo-stats.sh [repo-dir]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

REPO_DIR="${1:-.}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [repo-dir]

Print commit count, top contributors, most-modified files, and branch list.

Arguments:
  repo-dir    Path to the git repository (default: current directory)

Options:
  -h, --help  Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") /opt/myrepo
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        *) REPO_DIR="$1"; shift ;;
    esac
done

check_dependency git

cd "$REPO_DIR"

if ! git rev-parse --git-dir &>/dev/null; then
    log_error "Not a git repository: ${REPO_DIR}"
    exit 1
fi

REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")

log_info "Repository: ${REPO_NAME}"
echo ""

echo "=== Commit count ==="
git rev-list --count HEAD

echo ""
echo "=== Top 10 contributors ==="
git shortlog -sn --no-merges HEAD | head -10

echo ""
echo "=== 10 most modified files ==="
git log --pretty=format: --name-only | grep -v '^$' | sort | uniq -c | sort -rn | head -10

echo ""
echo "=== Remote branches ==="
git branch -r

echo ""
echo "=== Local branches ==="
git branch
