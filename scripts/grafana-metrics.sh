#!/bin/bash
# grafana-metrics.sh — Push custom metrics to Grafana via the HTTP API (Prometheus remote write or Graphite).
# Usage: ./grafana-metrics.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_API_KEY="${GRAFANA_API_KEY:-}"
METRIC_NAME="${METRIC_NAME:-custom.metric}"
METRIC_VALUE="${METRIC_VALUE:-0}"
METRIC_TAGS="${METRIC_TAGS:-}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Push a custom metric datapoint to Grafana using the Graphite data source API.

Options:
  --url     URL    Grafana base URL         (env: GRAFANA_URL,    default: ${GRAFANA_URL})
  --api-key KEY    Grafana API key          (env: GRAFANA_API_KEY)
  --name    NAME   Metric name (dot-path)   (env: METRIC_NAME,   default: ${METRIC_NAME})
  --value   NUM    Metric value             (env: METRIC_VALUE,  default: ${METRIC_VALUE})
  --tags    TAGS   Semicolon-separated tags (env: METRIC_TAGS)
  -h, --help       Show this help message

Examples:
  $(basename "$0") --name app.error.rate --value 0.02
  GRAFANA_URL=http://grafana:3000 GRAFANA_API_KEY=myk3y $(basename "$0") --name cpu.usage --value 42
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --url)     GRAFANA_URL="$2";     shift 2 ;;
        --api-key) GRAFANA_API_KEY="$2"; shift 2 ;;
        --name)    METRIC_NAME="$2";     shift 2 ;;
        --value)   METRIC_VALUE="$2";    shift 2 ;;
        --tags)    METRIC_TAGS="$2";     shift 2 ;;
        -h|--help) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

check_dependency curl

if [[ -z "$GRAFANA_API_KEY" ]]; then
    log_error "GRAFANA_API_KEY is required (--api-key or env var)."
    exit 1
fi

TIMESTAMP=$(date +%s)

PAYLOAD=$(jq -n \
    --arg name  "$METRIC_NAME" \
    --argjson value "$METRIC_VALUE" \
    --argjson time  "$TIMESTAMP" \
    '[{"name": $name, "value": $value, "time": $time}]')

log_info "Pushing metric '${METRIC_NAME}=${METRIC_VALUE}' to ${GRAFANA_URL}..."

RESPONSE=$(curl --silent --fail --show-error \
    -X POST "${GRAFANA_URL}/api/tsdb/query" \
    -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD") || {
    log_error "Failed to push metric to Grafana."
    exit 2
}

log_info "Metric pushed successfully."
if [[ -n "$RESPONSE" ]]; then
    echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
fi
