#!/bin/bash
# log-file-cleanup.sh — Delete log files older than a specified number of days.
# Usage: ./log-file-cleanup.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

LOG_DIR="${LOG_DIR:-/var/log}"
MAX_DAYS="${MAX_DAYS:-30}"
DRY_RUN=false
LOG_PATTERN="${LOG_PATTERN:-*.log}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Delete log files matching a pattern that are older than MAX_DAYS.
Supports --dry-run to preview what would be deleted.

Options:
  --dir     PATH    Log directory to clean   (env: LOG_DIR,     default: ${LOG_DIR})
  --days    N       Delete files older than N days (env: MAX_DAYS, default: ${MAX_DAYS})
  --pattern GLOB    Filename glob pattern    (env: LOG_PATTERN, default: ${LOG_PATTERN})
  --dry-run         Print files that would be deleted; make no changes
  -h, --help        Show this help message

Examples:
  $(basename "$0") --dir /opt/app/logs --days 14
  $(basename "$0") --dry-run
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)     LOG_DIR="$2";     shift 2 ;;
        --days)    MAX_DAYS="$2";    shift 2 ;;
        --pattern) LOG_PATTERN="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true;     shift   ;;
        -h|--help) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

if [[ ! -d "$LOG_DIR" ]]; then
    log_error "Log directory does not exist: ${LOG_DIR}"
    exit 1
fi

log_info "Scanning ${LOG_DIR} for ${LOG_PATTERN} files older than ${MAX_DAYS} days..."

count=0
while IFS= read -r -d '' file; do
    if "$DRY_RUN"; then
        log_warn "[DRY RUN] Would delete: ${file}"
    else
        rm -f -- "$file"
        log_info "Deleted: ${file}"
    fi
    count=$(( count + 1 ))
done < <(find "$LOG_DIR" -name "$LOG_PATTERN" -mtime "+${MAX_DAYS}" -type f -print0)

if [[ "$count" -eq 0 ]]; then
    log_info "No files found matching criteria."
else
    log_info "${count} file(s) processed."
fi
