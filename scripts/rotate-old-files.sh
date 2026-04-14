#!/bin/bash
# rotate-old-files.sh — Archive files older than DAYS days from a source directory.
# Usage: ./rotate-old-files.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

SOURCE_DIR="${SOURCE_DIR:-/opt/app/data}"
ARCHIVE_DIR="${ARCHIVE_DIR:-/opt/app/archive}"
DAYS="${DAYS:-30}"
DRY_RUN=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Move files older than DAYS days from SOURCE_DIR to ARCHIVE_DIR.
Supports --dry-run to preview what would be moved.

Options:
  --src   PATH    Source directory       (env: SOURCE_DIR,  default: ${SOURCE_DIR})
  --dest  PATH    Archive directory      (env: ARCHIVE_DIR, default: ${ARCHIVE_DIR})
  --days  N       Age threshold in days  (env: DAYS,        default: ${DAYS})
  --dry-run       Print what would move; make no changes
  -h, --help      Show this help message

Examples:
  $(basename "$0") --days 14 --dry-run
  $(basename "$0") --src /data/logs --dest /backup/logs --days 7
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --src)     SOURCE_DIR="$2";  shift 2 ;;
        --dest)    ARCHIVE_DIR="$2"; shift 2 ;;
        --days)    DAYS="$2";        shift 2 ;;
        --dry-run) DRY_RUN=true;     shift   ;;
        -h|--help) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

if [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "Source directory does not exist: ${SOURCE_DIR}"
    exit 1
fi

if ! "$DRY_RUN"; then
    mkdir -p "$ARCHIVE_DIR"
fi

log_info "Searching ${SOURCE_DIR} for files older than ${DAYS} days..."

count=0
while IFS= read -r -d '' file; do
    dest="${ARCHIVE_DIR}/$(basename "${file}")"
    if "$DRY_RUN"; then
        log_warn "[DRY RUN] Would move: ${file} → ${dest}"
    else
        mv -- "$file" "$dest"
        log_info "Moved: ${file} → ${dest}"
    fi
    count=$(( count + 1 ))
done < <(find "$SOURCE_DIR" -maxdepth 1 -type f -mtime "+${DAYS}" -print0)

if [[ "$count" -eq 0 ]]; then
    log_info "No files found older than ${DAYS} days."
else
    log_info "${count} file(s) processed."
fi
