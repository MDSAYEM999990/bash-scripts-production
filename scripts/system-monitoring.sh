#!/bin/bash
# system-monitoring.sh — Check CPU, memory, and disk usage against thresholds and alert.
# Usage: ./system-monitoring.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

CPU_THRESHOLD="${CPU_THRESHOLD:-90}"
MEM_THRESHOLD="${MEM_THRESHOLD:-85}"
DISK_THRESHOLD="${DISK_THRESHOLD:-75}"
LOGFILE="${LOGFILE:-/var/log/system_monitor.log}"
ALERT_EMAIL="${ALERT_EMAIL:-}"
DISK_PATH="${DISK_PATH:-/}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Check CPU, memory, and disk usage. Log and optionally email alerts when any
metric exceeds its threshold.

Options:
  --cpu-threshold  N    CPU alert percentage  (env: CPU_THRESHOLD,  default: ${CPU_THRESHOLD})
  --mem-threshold  N    Mem alert percentage  (env: MEM_THRESHOLD,  default: ${MEM_THRESHOLD})
  --disk-threshold N    Disk alert percentage (env: DISK_THRESHOLD, default: ${DISK_THRESHOLD})
  --log-file       PATH Log output file       (env: LOGFILE,        default: ${LOGFILE})
  --email          ADDR Email for alerts      (env: ALERT_EMAIL)
  --disk-path      PATH Filesystem to check  (default: /)
  -h, --help            Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --cpu-threshold 80 --email ops@example.com
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cpu-threshold)  CPU_THRESHOLD="$2";  shift 2 ;;
        --mem-threshold)  MEM_THRESHOLD="$2";  shift 2 ;;
        --disk-threshold) DISK_THRESHOLD="$2"; shift 2 ;;
        --log-file)       LOGFILE="$2";        shift 2 ;;
        --email)          ALERT_EMAIL="$2";    shift 2 ;;
        --disk-path)      DISK_PATH="$2";      shift 2 ;;
        -h|--help)        usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

send_alert() {
    local subject="$1"
    local message="$2"
    echo "$(date): ${message}" | tee -a "$LOGFILE"
    if [[ -n "$ALERT_EMAIL" ]] && command -v mail &>/dev/null; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL" || true
    fi
}

log_info "Checking system resources (CPU>${CPU_THRESHOLD}%, MEM>${MEM_THRESHOLD}%, DISK>${DISK_THRESHOLD}%)..."

# CPU — grep -c "Cpu" exits 1 on 0 matches; guard the pipeline with || true
CPU_LINE=$(top -bn1 | grep -m1 "Cpu(s)" || top -bn1 | grep -m1 "cpu" || true)
if [[ -n "$CPU_LINE" ]]; then
    cpu_usage=$(echo "$CPU_LINE" | awk '{for(i=1;i<=NF;i++) if($i~/^[0-9]+\.?[0-9]*$/ && $(i+1)~/id/) {print 100-$i; exit}}' || echo "0")
    cpu_int="${cpu_usage%.*}"
    if [[ -n "$cpu_int" ]] && (( cpu_int > CPU_THRESHOLD )); then
        send_alert "CPU Usage Alert" "High CPU usage detected: ${cpu_usage}%"
    else
        log_info "CPU usage: ${cpu_usage}%"
    fi
fi

# Memory — 'free' is Linux-only; skip gracefully on macOS
if command -v free &>/dev/null; then
    mem_usage=$(free | awk '/Mem/ {printf("%.0f"), $3/$2 * 100}' || echo "0")
    if (( mem_usage > MEM_THRESHOLD )); then
        send_alert "Memory Usage Alert" "High Memory usage detected: ${mem_usage}%"
    else
        log_info "Memory usage: ${mem_usage}%"
    fi
fi

# Disk
disk_usage=$(df "$DISK_PATH" | awk 'END{print $5}' | tr -d '%' || echo "0")
if (( disk_usage > DISK_THRESHOLD )); then
    send_alert "Disk Usage Alert" "High Disk usage detected on ${DISK_PATH}: ${disk_usage}%"
else
    log_info "Disk usage (${DISK_PATH}): ${disk_usage}%"
fi
