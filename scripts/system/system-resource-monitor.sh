#!/bin/bash
# system-resource-monitor.sh — Continuously log CPU and memory usage to a file.
# Usage: ./system-resource-monitor.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

LOG_FILE="${LOG_FILE:-/var/log/resource_monitor.log}"
INTERVAL="${INTERVAL:-60}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Continuously sample CPU and memory usage at a fixed interval and append each
reading to a log file. Runs until interrupted (Ctrl-C or SIGTERM).

Options:
  --log-file PATH    Path to output log file (env: LOG_FILE,  default: ${LOG_FILE})
  --interval SECS    Seconds between samples (env: INTERVAL,  default: ${INTERVAL})
  -h, --help         Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --log-file /tmp/resources.log --interval 30
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --log-file) LOG_FILE="$2"; shift 2 ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        -h|--help)  usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

get_cpu_usage() {
    local cpu_line
    cpu_line=$(top -bn1 | grep -m1 "Cpu(s)" || top -bn1 | grep -m1 "cpu" || true)
    if [[ -z "$cpu_line" ]]; then echo "N/A"; return; fi
    echo "$cpu_line" | awk '{
        for(i=1;i<=NF;i++) if($i~/^[0-9]+\.?[0-9]*$/ && $(i+1)~/id/) {
            printf "%.1f%%", 100-$i; exit
        }
    }' || echo "N/A"
}

get_memory_usage() {
    if command -v free &>/dev/null; then
        free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2}' || echo "N/A"
    else
        echo "N/A"
    fi
}

log_info "Starting resource monitor: logging to ${LOG_FILE} every ${INTERVAL}s (Ctrl-C to stop)."

# Ensure log directory exists — || true so we don't abort if already present
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    CPU_USAGE=$(get_cpu_usage)
    MEM_USAGE=$(get_memory_usage)
    echo "${TIMESTAMP} - CPU: ${CPU_USAGE}, Memory: ${MEM_USAGE}" | tee -a "$LOG_FILE"
    sleep "$INTERVAL"
done
