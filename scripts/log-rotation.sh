#!/bin/bash
# log-rotation.sh — Rotate a log file by compressing and renaming it with a timestamp.
# Usage: ./log-rotation.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

LOG_FILE="${LOG_FILE:-/var/log/app.log}"
MAX_SIZE_MB="${MAX_SIZE_MB:-100}"
BACKUP_KEEP="${BACKUP_KEEP:-7}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Rotate a log file when it exceeds a size threshold:
  1. Compress the existing log to <log>.YYYYMMDD_HHMMSS.gz
  2. Truncate the original file (preserving its inode/permissions)
  3. Delete rotated files beyond the retention count

Options:
  --file      PATH   Log file to rotate        (env: LOG_FILE,    default: ${LOG_FILE})
  --max-mb    N      Rotate when file exceeds N MB (env: MAX_SIZE_MB, default: ${MAX_SIZE_MB})
  --keep      N      Number of rotated files to keep (env: BACKUP_KEEP, default: ${BACKUP_KEEP})
  -h, --help         Show this help message

Examples:
  $(basename "$0") --file /opt/app/app.log --max-mb 50 --keep 14
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --file)   LOG_FILE="$2";      shift 2 ;;
        --max-mb) MAX_SIZE_MB="$2";   shift 2 ;;
        --keep)   BACKUP_KEEP="$2";   shift 2 ;;
        -h|--help) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

check_dependency gzip

if [[ ! -f "$LOG_FILE" ]]; then
    log_error "Log file not found: ${LOG_FILE}"
    exit 1
fi

SIZE_BYTES=$(wc -c < "$LOG_FILE")
MAX_BYTES=$(( MAX_SIZE_MB * 1024 * 1024 ))

if [[ "$SIZE_BYTES" -lt "$MAX_BYTES" ]]; then
    log_info "Log file is $(( SIZE_BYTES / 1024 ))KB — no rotation needed (threshold: ${MAX_SIZE_MB}MB)."
    exit 0
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE="${LOG_FILE}.${TIMESTAMP}.gz"

log_info "Rotating ${LOG_FILE} ($(( SIZE_BYTES / 1024 / 1024 ))MB) → ${ARCHIVE}..."
gzip --keep "$LOG_FILE" --stdout > "$ARCHIVE"
# Truncate in-place to preserve inode for open file handles
: > "$LOG_FILE"
log_info "Rotation complete."

# Prune old rotated files (while-read loop avoids mapfile — compatible with bash 3.2)
old_archives=()
while IFS= read -r f; do
    old_archives+=("$f")
done < <(ls -t "${LOG_FILE}".*.gz 2>/dev/null)
if [[ "${#old_archives[@]}" -gt "$BACKUP_KEEP" ]]; then
    to_delete=("${old_archives[@]:$BACKUP_KEEP}")
    for f in "${to_delete[@]}"; do
        rm -f -- "$f"
        log_info "Pruned old archive: ${f}"
    done
fi

log_info "Log rotation finished. Keeping ${BACKUP_KEEP} archives."
