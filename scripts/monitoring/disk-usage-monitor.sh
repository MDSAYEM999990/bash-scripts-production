#!/bin/bash
# disk-usage-monitor.sh — Alert when disk usage exceeds a threshold.
# Usage: ./disk-usage-monitor.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

THRESHOLD="${THRESHOLD:-80}"
ALERT_EMAIL="${ALERT_EMAIL:-admin@example.com}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Monitor all mounted filesystems and alert when usage exceeds a threshold.
Sends email alerts if the 'mail' command is available; always prints to stdout.

Options:
  --threshold PCT   Alert threshold percentage (env: THRESHOLD, default: ${THRESHOLD})
  --email     ADDR  Alert email address        (env: ALERT_EMAIL, default: ${ALERT_EMAIL})
  -h, --help        Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --threshold 90 --email ops@example.com
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --threshold) THRESHOLD="$2";   shift 2 ;;
        --email)     ALERT_EMAIL="$2"; shift 2 ;;
        -h|--help)   usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

log_info "Checking disk usage (threshold: ${THRESHOLD}%)..."

alerted=0
while read -r usage mount_point; do
    usage_int="${usage//%/}"
    if [[ "$usage_int" -ge "$THRESHOLD" ]]; then
        msg="Disk usage on ${mount_point} has reached ${usage}%."
        log_warn "$msg"
        if command -v mail &>/dev/null; then
            echo "$msg" | mail -s "Disk Usage Alert: ${mount_point}" "$ALERT_EMAIL"
            log_info "Alert email sent to ${ALERT_EMAIL}."
        fi
        alerted=$(( alerted + 1 ))
    fi
done < <(df -h | awk 'NR>1 {print $5, $6}')

if [[ "$alerted" -eq 0 ]]; then
    log_info "All filesystems are within the ${THRESHOLD}% threshold."
fi
