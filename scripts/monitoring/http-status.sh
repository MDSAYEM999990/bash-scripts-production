#!/bin/bash
# http-status.sh — Check HTTP status codes for a list of URLs.
# Usage: ./http-status.sh [options] [url ...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

TIMEOUT=10
URLS=()

usage() {
    cat <<EOF
Usage: $(basename "$0") [options] [url ...]

Perform an HTTP HEAD request for each URL and report the status code.
Non-2xx responses are printed as warnings; connection failures as errors.
Exits 2 if any URL fails.

Options:
  --timeout SEC   Request timeout in seconds (default: ${TIMEOUT})
  -h, --help      Show this help message

Examples:
  $(basename "$0") https://example.com https://google.com
  $(basename "$0") --timeout 5 https://api.example.com/health
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --timeout) TIMEOUT="$2"; shift 2 ;;
        -h|--help) usage ;;
        *)         URLS+=("$1"); shift ;;
    esac
done

if [[ ${#URLS[@]} -eq 0 ]]; then
    log_error "At least one URL is required."
    exit 1
fi

check_dependency curl

failed=0
for url in "${URLS[@]}"; do
    status_code=$(curl --silent --output /dev/null --write-out "%{http_code}" \
        --max-time "$TIMEOUT" --head "$url") || status_code="000"

    if [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]; then
        log_info "OK  [${status_code}] ${url}"
    elif [[ "$status_code" == "000" ]]; then
        log_error "FAIL [---] ${url} (connection failed or timed out)"
        failed=$(( failed + 1 ))
    else
        log_warn "WARN [${status_code}] ${url}"
        failed=$(( failed + 1 ))
    fi
done

if [[ "$failed" -gt 0 ]]; then
    log_error "${failed} URL(s) returned non-OK status."
    exit 2
fi
