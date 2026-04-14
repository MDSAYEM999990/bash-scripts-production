#!/bin/bash
# backup.sh — Create a compressed archive backup of system directories.
# Usage: ./backup.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

BACKUP_DIR="${BACKUP_DIR:-/var/backups}"
BACKUP_FILES="${BACKUP_FILES:-/etc /var/www /home /var/lib /var/mail /opt}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Create a timestamped .tgz archive backup of configured directories.

Options:
  --dest  DIR      Backup destination directory (env: BACKUP_DIR,   default: ${BACKUP_DIR})
  --src   PATHS    Space-separated list of paths to back up
                   (env: BACKUP_FILES, default: ${BACKUP_FILES})
  -h, --help       Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --dest /mnt/nas/backups --src "/etc /home"
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dest) BACKUP_DIR="$2";   shift 2 ;;
        --src)  BACKUP_FILES="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

check_dependency tar

DAY=$(date +%Y-%m-%d)
HOSTNAME=$(hostname -s)
ARCHIVE_FILE="${HOSTNAME}-${DAY}.tgz"

mkdir -p "${BACKUP_DIR}"

log_info "Starting backup to ${BACKUP_DIR}/${ARCHIVE_FILE}..."
log_info "Source paths: ${BACKUP_FILES}"

# Word-split BACKUP_FILES intentionally — it is a space-delimited path list
# shellcheck disable=SC2086
tar czf "${BACKUP_DIR}/${ARCHIVE_FILE}" ${BACKUP_FILES}

log_info "Backup completed successfully."
ls -lh "${BACKUP_DIR}/${ARCHIVE_FILE}"
