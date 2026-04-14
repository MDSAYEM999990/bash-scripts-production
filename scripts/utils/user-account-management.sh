#!/bin/bash
# user-account-management.sh — Create a user, assign a password, and add to a group.
# Usage: ./user-account-management.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

USERNAME="${USERNAME:-}"
PASSWORD="${PASSWORD:-}"
GROUP="${GROUP:-}"
SHELL="${USER_SHELL:-/bin/bash}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Create a new user account and add it to a group. The group is created if it
does not already exist. Requires root or sudo privileges.

Options:
  --username USER    Login name for the new user (env: USERNAME)
  --password PASS    Initial password             (env: PASSWORD)
  --group    GROUP   Primary group to assign      (env: GROUP)
  --shell    PATH    Login shell                  (env: USER_SHELL, default: ${SHELL})
  -h, --help         Show this help message

Examples:
  sudo $(basename "$0") --username alice --password secret --group developers
  sudo $(basename "$0") --username deploy --password changeme --group deployers --shell /bin/sh
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --username) USERNAME="$2"; shift 2 ;;
        --password) PASSWORD="$2"; shift 2 ;;
        --group)    GROUP="$2";    shift 2 ;;
        --shell)    SHELL="$2";    shift 2 ;;
        -h|--help)  usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

check_dependency useradd
check_dependency groupadd
check_dependency getent
check_dependency chpasswd

for var in USERNAME PASSWORD GROUP; do
    if [[ -z "${!var}" ]]; then
        log_error "--${var,,} (or env var ${var}) is required."
        exit 1
    fi
done

if [[ "$(id -u)" -ne 0 ]]; then
    log_error "This script must be run as root."
    exit 1
fi

if ! getent group "$GROUP" > /dev/null 2>&1; then
    log_info "Group '${GROUP}' does not exist — creating..."
    groupadd "$GROUP"
    log_info "Group '${GROUP}' created."
else
    log_info "Group '${GROUP}' already exists."
fi

if id -u "$USERNAME" > /dev/null 2>&1; then
    log_warn "User '${USERNAME}' already exists. No changes made."
    exit 0
fi

log_info "Creating user '${USERNAME}' in group '${GROUP}'..."
useradd -m -g "$GROUP" -s "$SHELL" "$USERNAME"
echo "${USERNAME}:${PASSWORD}" | chpasswd
log_info "User '${USERNAME}' created and added to group '${GROUP}'."
