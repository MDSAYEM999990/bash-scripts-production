#!/bin/bash
# log-aggregator.sh — Tail multiple log files and write timestamped output to one file
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "${SCRIPT_DIR}/../lib/utils.sh"

OUTPUT_FILE=""
TAIL_LINES=50
FOLLOW=false
declare -a LOG_FILES

usage() {
    cat <<EOF
Usage: $(basename "$0") [options] FILE [FILE ...]

Tail one or more log files and write all output to a single aggregated file,
prepending each line with a UTC timestamp and the source filename.

Arguments:
  FILE ...            One or more log file paths to aggregate     (required)

Options:
  --output FILE       Destination file for aggregated output       (required)
  --tail N            Number of most-recent lines per file         (default: 50)
  --follow            Continuously follow all files (like tail -f)
  -h, --help          Show this help message

Examples:
  $(basename "$0") --output /tmp/all.log /var/log/nginx/access.log /var/log/app.log
  $(basename "$0") --output combined.log --tail 100 app.log worker.log
  $(basename "$0") --output live.log --follow /var/log/app/*.log
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)  OUTPUT_FILE="$2"; shift 2 ;;
        --tail)    TAIL_LINES="$2";  shift 2 ;;
        --follow)  FOLLOW=true;      shift ;;
        -h|--help) usage; exit 0 ;;
        -*) log_error "Unknown option: $1"; usage; exit 1 ;;
        *)  LOG_FILES+=("$1"); shift ;;
    esac
done

if [[ ${#LOG_FILES[@]} -eq 0 ]]; then
    log_error "At least one log file is required."
    usage
    exit 1
fi

if [[ -z "$OUTPUT_FILE" ]]; then
    log_error "--output file is required."
    usage
    exit 1
fi

# Validate all input files exist
for f in "${LOG_FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        log_error "Log file not found: ${f}"
        exit 2
    fi
done

OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
[[ "$OUTPUT_DIR" != "." ]] && mkdir -p "$OUTPUT_DIR"

log_info "Aggregating ${#LOG_FILES[@]} log file(s) → ${OUTPUT_FILE}"

aggregate_file() {
    local src="$1"
    local label
    label=$(basename "$src")
    tail -n "${TAIL_LINES}" "$src" | while IFS= read -r line; do
        printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$label" "$line"
    done >> "$OUTPUT_FILE"
}

# Snapshot pass: tail last N lines from each file
for f in "${LOG_FILES[@]}"; do
    aggregate_file "$f"
done

if [[ "$FOLLOW" == "true" ]]; then
    log_info "Following log files... (Ctrl+C to stop)"
    tail -q -f "${LOG_FILES[@]}" | while IFS= read -r line; do
        printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$line"
    done >> "$OUTPUT_FILE"
fi

log_info "Aggregation complete: ${OUTPUT_FILE}"
exit 0
