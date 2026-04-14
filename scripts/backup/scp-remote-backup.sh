#!/bin/bash
# scp-remote-backup.sh — Create a tar archive of a directory and copy it to a remote host.
# Usage: ./scp-remote-backup.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

SOURCE_DIR="${SOURCE_DIR:-}"
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_USER="${REMOTE_USER:-}"
REMOTE_DIR="${REMOTE_DIR:-/backup}"
SSH_KEY="${SSH_KEY:-}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Compress a local directory to a timestamped .tar.gz archive and copy it to a
remote host via scp. The local archive is deleted after a successful transfer.

Options:
  --src        PATH     Local directory to back up   (env: SOURCE_DIR)
  --host       HOST     Remote host                  (env: REMOTE_HOST)
  --user       USER     Remote SSH user              (env: REMOTE_USER)
  --remote-dir PATH     Destination path on host     (env: REMOTE_DIR, default: ${REMOTE_DIR})
  --key        FILE     SSH private key              (env: SSH_KEY)
  -h, --help            Show this help message

Examples:
  $(basename "$0") --src /opt/app --host backup.example.com --user deploy
  $(basename "$0") --src /data --host 10.0.0.5 --user admin --key ~/.ssh/id_rsa
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --src)        SOURCE_DIR="$2";  shift 2 ;;
        --host)       REMOTE_HOST="$2"; shift 2 ;;
        --user)       REMOTE_USER="$2"; shift 2 ;;
        --remote-dir) REMOTE_DIR="$2";  shift 2 ;;
        --key)        SSH_KEY="$2";     shift 2 ;;
        -h|--help)    usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

check_dependency tar
check_dependency scp

for var in SOURCE_DIR REMOTE_HOST REMOTE_USER; do
    if [[ -z "${!var}" ]]; then
        log_error "--${var,,} (or env var ${var}) is required."
        exit 1
    fi
done

if [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "Source directory does not exist: ${SOURCE_DIR}"
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_NAME="$(basename "${SOURCE_DIR}")_${TIMESTAMP}.tar.gz"
TMP_ARCHIVE="${TMPDIR:-/tmp}/${ARCHIVE_NAME}"

log_info "Creating archive: ${TMP_ARCHIVE}..."
tar -czf "$TMP_ARCHIVE" -C "$(dirname "${SOURCE_DIR}")" "$(basename "${SOURCE_DIR}")"

SCP_OPTS=(-o StrictHostKeyChecking=no)
[[ -n "$SSH_KEY" ]] && SCP_OPTS+=(-i "$SSH_KEY")

log_info "Copying archive to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}..."
scp "${SCP_OPTS[@]}" "$TMP_ARCHIVE" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"

rm -f -- "$TMP_ARCHIVE"
log_info "Backup complete: ${REMOTE_DIR}/${ARCHIVE_NAME} on ${REMOTE_HOST}."
