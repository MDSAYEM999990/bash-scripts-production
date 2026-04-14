#!/bin/bash
# monitor-open-ports.sh — List open listening ports on the local machine.
# Usage: ./monitor-open-ports.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

EXPECTED_PORTS=()
ALERT_UNEXPECTED=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

List all listening TCP/UDP ports. Optionally alert when unexpected ports are open.

Options:
  --expect  PORT[,PORT,...]  Comma-separated list of expected open ports
  --alert                    Exit 2 if any unexpected ports are found
  -h, --help                 Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --expect 22,80,443 --alert
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --expect) IFS=',' read -ra EXPECTED_PORTS <<< "$2"; shift 2 ;;
        --alert)  ALERT_UNEXPECTED=true; shift ;;
        -h|--help) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

# Prefer ss (modern), fall back to netstat
if command -v ss &>/dev/null; then
    NET_CMD="ss"
elif command -v netstat &>/dev/null; then
    NET_CMD="netstat"
else
    log_error "Neither 'ss' nor 'netstat' is available. Install iproute2 (ss) or net-tools (netstat)."
    exit 1
fi

log_info "Listening ports (via ${NET_CMD}):"
echo ""

if [[ "$NET_CMD" == "ss" ]]; then
    ss -tlnup 2>/dev/null
else
    netstat -tlnup 2>/dev/null
fi

if [[ ${#EXPECTED_PORTS[@]} -eq 0 ]]; then
    exit 0
fi

# Build a set of actually-open ports
if [[ "$NET_CMD" == "ss" ]]; then
    OPEN_PORTS=$(ss -tlnup 2>/dev/null | awk 'NR>1 {print $5}' | grep -oE ':[0-9]+$' | tr -d ':' | sort -u || true)
else
    OPEN_PORTS=$(netstat -tlnup 2>/dev/null | awk 'NR>2 {print $4}' | grep -oE ':[0-9]+$' | tr -d ':' | sort -u || true)
fi

unexpected=0
for port in $OPEN_PORTS; do
    is_expected=false
    for ep in "${EXPECTED_PORTS[@]}"; do
        [[ "$port" == "$ep" ]] && is_expected=true && break
    done
    if ! "$is_expected"; then
        log_warn "Unexpected open port: ${port}"
        unexpected=$(( unexpected + 1 ))
    fi
done

if "$ALERT_UNEXPECTED" && [[ "$unexpected" -gt 0 ]]; then
    log_error "${unexpected} unexpected port(s) detected."
    exit 2
fi
