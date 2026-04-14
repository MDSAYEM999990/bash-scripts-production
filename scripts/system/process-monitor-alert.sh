#!/bin/bash
# process-monitor-alert.sh — Alert when a process is not running.
# Usage: ./process-monitor-alert.sh [options] <process-name>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

PROCESS_NAME=""
ALERT_EMAIL="${ALERT_EMAIL:-admin@example.com}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options] <process-name>

Check whether a process is running. Send an alert email if it is not found.

Arguments:
  process-name      Name to search for with pgrep

Options:
  --email ADDR      Alert recipient email     (env: ALERT_EMAIL, default: ${ALERT_EMAIL})
  -h, --help        Show this help message

Examples:
  $(basename "$0") nginx
  $(basename "$0") --email ops@company.com mysqld
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --email)   ALERT_EMAIL="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *)         PROCESS_NAME="$1"; shift ;;
    esac
done

if [[ -z "$PROCESS_NAME" ]]; then
    log_error "A process name is required."
    usage
    exit 1
fi

check_dependency pgrep

if pgrep -x "$PROCESS_NAME" &>/dev/null; then
    log_info "Process '${PROCESS_NAME}' is running."
    exit 0
fi

SUBJECT="Process Alert: '${PROCESS_NAME}' is not running on $(hostname)"
BODY="The process '${PROCESS_NAME}' was not found on $(hostname) at $(date)."

log_warn "${BODY}"

if command -v mail &>/dev/null; then
    echo "$BODY" | mail -s "$SUBJECT" "$ALERT_EMAIL"
    log_info "Alert sent to ${ALERT_EMAIL}."
else
    log_warn "mail command not available — alert not sent."
fi

exit 2
