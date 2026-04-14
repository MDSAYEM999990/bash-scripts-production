#!/bin/bash
# rsync-backup.sh — Rsync a local directory to a remote destination.
# Usage: ./rsync-backup.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

SOURCE_DIR="${SOURCE_DIR:-}"
REMOTE_DEST="${REMOTE_DEST:-}"
SSH_KEY="${SSH_KEY:-}"
DRY_RUN=false
DELETE_EXTRANEOUS=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Perform an incremental rsync backup from a local directory to a remote path.

Options:
  --src     PATH     Local source directory        (env: SOURCE_DIR)
  --dest    USER@H:P Remote destination            (env: REMOTE_DEST)
  --key     FILE     SSH private key path          (env: SSH_KEY)
  --dry-run          Show what would be transferred; transfer nothing
  --delete           Delete files on destination not in source
  -h, --help         Show this help message

Examples:
  $(basename "$0") --src /data --dest user@host:/backup/data --key ~/.ssh/id_rsa
  $(basename "$0") --dry-run --src /var/www --dest deploy@web:/backup/www
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --src)     SOURCE_DIR="$2";       shift 2 ;;
        --dest)    REMOTE_DEST="$2";      shift 2 ;;
        --key)     SSH_KEY="$2";          shift 2 ;;
        --dry-run) DRY_RUN=true;          shift   ;;
        --delete)  DELETE_EXTRANEOUS=true; shift  ;;
        -h|--help) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

check_dependency rsync

if [[ -z "$SOURCE_DIR" ]]; then
    log_error "--src (or env var SOURCE_DIR) is required."
    exit 1
fi
if [[ -z "$REMOTE_DEST" ]]; then
    log_error "--dest (or env var REMOTE_DEST) is required."
    exit 1
fi
if [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "Source directory does not exist: ${SOURCE_DIR}"
    exit 1
fi

RSYNC_OPTS=(-avz --progress)
"$DRY_RUN"             && RSYNC_OPTS+=("--dry-run")
"$DELETE_EXTRANEOUS"   && RSYNC_OPTS+=("--delete")
[[ -n "$SSH_KEY" ]]    && RSYNC_OPTS+=(-e "ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no")

log_info "Syncing ${SOURCE_DIR} → ${REMOTE_DEST}..."
rsync "${RSYNC_OPTS[@]}" "${SOURCE_DIR}/" "${REMOTE_DEST}/"
log_info "Backup complete."
