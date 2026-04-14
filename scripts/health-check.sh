#!/bin/bash
# health-check.sh — Check the health of one or more system services.
# Usage: ./health-check.sh [options] [service ...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

SERVICES=()
RESTART_ON_FAIL=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [options] [service ...]

Check systemd service status. Optionally restart failed services.
If no services are specified, checks nginx, apache2, mysql, and postgresql.

Options:
  --restart     Attempt to restart any stopped/failed service
  -h, --help    Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") nginx mysql
  $(basename "$0") --restart nginx
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --restart) RESTART_ON_FAIL=true; shift ;;
        -h|--help) usage ;;
        *)         SERVICES+=("$1"); shift ;;
    esac
done

if [[ ${#SERVICES[@]} -eq 0 ]]; then
    SERVICES=(nginx apache2 mysql postgresql)
fi

check_dependency systemctl

failed=0
for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$service"; then
        log_info "Service '${service}' is running."
    else
        log_warn "Service '${service}' is NOT running."
        if "$RESTART_ON_FAIL"; then
            log_info "Attempting to restart '${service}'..."
            if systemctl restart "$service"; then
                log_info "Service '${service}' restarted successfully."
            else
                log_error "Failed to restart service '${service}'."
                failed=$(( failed + 1 ))
            fi
        else
            failed=$(( failed + 1 ))
        fi
    fi
done

if [[ "$failed" -gt 0 ]]; then
    log_error "${failed} service(s) are unhealthy."
    exit 2
fi

log_info "All checked services are healthy."
