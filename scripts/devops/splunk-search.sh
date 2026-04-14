#!/bin/bash
# splunk-search.sh — Execute a Splunk search query and print results.
# Usage: ./splunk-search.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

SPLUNK_HOST="${SPLUNK_HOST:-}"
SPLUNK_PORT="${SPLUNK_PORT:-8089}"
SPLUNK_USER="${SPLUNK_USER:-admin}"
SPLUNK_PASS="${SPLUNK_PASS:-}"
SEARCH_QUERY="${SEARCH_QUERY:-}"
EARLIEST="${EARLIEST:--15m}"
LATEST="${LATEST:-now}"
OUTPUT_MODE="${OUTPUT_MODE:-json}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Submit a Splunk search job, poll until complete, and print results.

Options:
  --host    HOST    Splunk management host    (env: SPLUNK_HOST)
  --port    PORT    Splunk management port    (env: SPLUNK_PORT, default: ${SPLUNK_PORT})
  --user    USER    Splunk username           (env: SPLUNK_USER, default: ${SPLUNK_USER})
  --pass    PASS    Splunk password           (env: SPLUNK_PASS)
  --query   QUERY   SPL search query         (env: SEARCH_QUERY)
  --earliest TIME   Earliest time bound      (env: EARLIEST,    default: ${EARLIEST})
  --latest   TIME   Latest time bound        (env: LATEST,      default: ${LATEST})
  --output  MODE    Results format           (env: OUTPUT_MODE, default: ${OUTPUT_MODE})
  -h, --help        Show this help message

Examples:
  $(basename "$0") --host splunk.example.com --pass secret --query "error | head 20"
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)     SPLUNK_HOST="$2";  shift 2 ;;
        --port)     SPLUNK_PORT="$2";  shift 2 ;;
        --user)     SPLUNK_USER="$2";  shift 2 ;;
        --pass)     SPLUNK_PASS="$2";  shift 2 ;;
        --query)    SEARCH_QUERY="$2"; shift 2 ;;
        --earliest) EARLIEST="$2";     shift 2 ;;
        --latest)   LATEST="$2";       shift 2 ;;
        --output)   OUTPUT_MODE="$2";  shift 2 ;;
        -h|--help)  usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

check_dependency curl
check_dependency jq

for var in SPLUNK_HOST SPLUNK_PASS SEARCH_QUERY; do
    if [[ -z "${!var}" ]]; then
        log_error "Missing required value for ${var} (use --${var,,//_/-} or env var ${var})."
        exit 1
    fi
done

BASE_URL="https://${SPLUNK_HOST}:${SPLUNK_PORT}"
CURL_OPTS=(--silent --show-error --insecure -u "${SPLUNK_USER}:${SPLUNK_PASS}")

log_info "Submitting search job..."
JOB_RESPONSE=$(curl "${CURL_OPTS[@]}" \
    -d "search=search ${SEARCH_QUERY}" \
    -d "earliest_time=${EARLIEST}" \
    -d "latest_time=${LATEST}" \
    "${BASE_URL}/services/search/jobs?output_mode=json")

SID=$(echo "$JOB_RESPONSE" | jq -r '.sid // empty')
if [[ -z "$SID" ]]; then
    log_error "Failed to create search job. Response: ${JOB_RESPONSE}"
    exit 2
fi

log_info "Search job created: SID=${SID}. Waiting for completion..."
while true; do
    JOB_STATUS=$(curl "${CURL_OPTS[@]}" \
        "${BASE_URL}/services/search/jobs/${SID}?output_mode=json")
    DISPATCH_STATE=$(echo "$JOB_STATUS" | jq -r '.entry[0].content.dispatchState // empty')

    if [[ "$DISPATCH_STATE" == "DONE" ]]; then
        break
    elif [[ "$DISPATCH_STATE" == "FAILED" ]]; then
        log_error "Search job failed."
        exit 2
    fi
    log_info "State: ${DISPATCH_STATE}. Waiting..."
done

log_info "Fetching results..."
curl "${CURL_OPTS[@]}" \
    "${BASE_URL}/services/search/jobs/${SID}/results?output_mode=${OUTPUT_MODE}"
