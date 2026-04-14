#!/bin/bash
# account-expiry-notify.sh — Notify about user accounts expiring within a threshold.
# Usage: ./account-expiry-notify.sh [--threshold DAYS] [--help]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

THRESHOLD=7

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Check for user accounts expiring within the threshold and print warnings.

Options:
  --threshold DAYS   Days before expiry to notify (default: ${THRESHOLD})
  -h, --help         Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --threshold 14
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --threshold) THRESHOLD="$2"; shift 2 ;;
        -h|--help)   usage ;;
        *)           log_error "Unknown option: $1"; usage ;;
    esac
done

check_dependency chage

log_info "Checking user accounts expiring in the next ${THRESHOLD} days..."

found=0
while IFS=: read -r username _ _ _ _ _ expiry_date _; do
    if [[ "$expiry_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        if command -v gdate &>/dev/null; then
            expiry_epoch=$(gdate -d "$expiry_date" +%s)  # macOS with coreutils
        else
            expiry_epoch=$(date -d "$expiry_date" +%s)   # Linux
        fi
        now_epoch=$(date +%s)
        days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
        if [[ "$days_left" -le "$THRESHOLD" ]]; then
            log_warn "User '${username}' account expires in ${days_left} day(s) (${expiry_date})."
            found=$(( found + 1 ))
        fi
    fi
done < <(getent shadow 2>/dev/null || true)

if [[ "$found" -eq 0 ]]; then
    log_info "No accounts expiring within ${THRESHOLD} days."
else
    log_warn "${found} account(s) expiring soon."
fi
