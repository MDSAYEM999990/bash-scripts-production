#!/bin/bash
# docker-log-monitor.sh — Monitor Docker container logs for error patterns and send alerts.
# Usage: ./docker-log-monitor.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

CONTAINER_NAME="${CONTAINER_NAME:-my-container}"
ERROR_PATTERN="${ERROR_PATTERN:-ERROR}"
OPSGENIE_API_KEY="${OPSGENIE_API_KEY:-}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Tail a Docker container's logs and send an OpsGenie alert on each matched line.

Options:
  --container NAME    Container name/ID       (env: CONTAINER_NAME,  default: ${CONTAINER_NAME})
  --pattern   REGEX   Log pattern to match    (env: ERROR_PATTERN,   default: ${ERROR_PATTERN})
  --api-key   KEY     OpsGenie API key        (env: OPSGENIE_API_KEY)
  -h, --help          Show this help message

Examples:
  $(basename "$0") --container my-app --pattern "CRITICAL|ERROR"
  OPSGENIE_API_KEY=mykey $(basename "$0") --container nginx
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --container) CONTAINER_NAME="$2";  shift 2 ;;
        --pattern)   ERROR_PATTERN="$2";   shift 2 ;;
        --api-key)   OPSGENIE_API_KEY="$2"; shift 2 ;;
        -h|--help)   usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

check_dependency docker
check_dependency curl

if [[ -z "$OPSGENIE_API_KEY" ]]; then
    log_warn "OPSGENIE_API_KEY not set — alerts will be printed only, not sent."
fi

log_info "Monitoring container '${CONTAINER_NAME}' for pattern '${ERROR_PATTERN}'..."

docker logs -f "$CONTAINER_NAME" 2>&1 | while IFS= read -r line; do
    if echo "$line" | grep -qE "$ERROR_PATTERN"; then
        log_warn "Pattern matched: ${line}"
        if [[ -n "$OPSGENIE_API_KEY" ]]; then
            curl --silent --fail --show-error \
                 -X POST "https://api.opsgenie.com/v2/alerts" \
                 -H "Authorization: GenieKey ${OPSGENIE_API_KEY}" \
                 -H "Content-Type: application/json" \
                 -d "{\"message\": \"Error in ${CONTAINER_NAME}\", \"description\": $(printf '%s' "$line" | jq -Rs .)}" \
            || log_warn "Failed to send OpsGenie alert."
        fi
    fi
done || true  # exits cleanly when container stops
