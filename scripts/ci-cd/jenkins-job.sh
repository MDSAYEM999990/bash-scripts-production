#!/bin/bash
# jenkins-job.sh — Trigger a Jenkins job and optionally poll for its result.
# Usage: ./jenkins-job.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
JOB_NAME="${JOB_NAME:-}"
JENKINS_USER="${JENKINS_USER:-}"
JENKINS_TOKEN="${JENKINS_TOKEN:-}"
WAIT_FOR_COMPLETION=false
POLL_INTERVAL=15
BUILD_PARAMS="${BUILD_PARAMS:-}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Trigger a Jenkins job build via the REST API.

Options:
  --url       URL    Jenkins base URL      (env: JENKINS_URL,   default: ${JENKINS_URL})
  --job       NAME   Job name              (env: JOB_NAME)
  --user      USER   Jenkins username      (env: JENKINS_USER)
  --token     TOKEN  API token or password (env: JENKINS_TOKEN)
  --params    KV     URL-encoded build params, e.g. "branch=main&env=prod"
  --wait             Poll until build completes
  --interval  SEC    Poll interval in seconds (default: ${POLL_INTERVAL})
  -h, --help         Show this help message

Examples:
  $(basename "$0") --job my-pipeline --user admin --token s3cr3t
  $(basename "$0") --job deploy --params "env=prod" --wait
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --url)      JENKINS_URL="$2";         shift 2 ;;
        --job)      JOB_NAME="$2";            shift 2 ;;
        --user)     JENKINS_USER="$2";        shift 2 ;;
        --token)    JENKINS_TOKEN="$2";       shift 2 ;;
        --params)   BUILD_PARAMS="$2";        shift 2 ;;
        --wait)     WAIT_FOR_COMPLETION=true; shift   ;;
        --interval) POLL_INTERVAL="$2";       shift 2 ;;
        -h|--help)  usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

check_dependency curl

if [[ -z "$JOB_NAME" ]]; then
    log_error "--job (or env var JOB_NAME) is required."
    exit 1
fi

AUTH_ARGS=()
if [[ -n "$JENKINS_USER" && -n "$JENKINS_TOKEN" ]]; then
    AUTH_ARGS=(-u "${JENKINS_USER}:${JENKINS_TOKEN}")
fi

if [[ -n "$BUILD_PARAMS" ]]; then
    TRIGGER_PATH="job/${JOB_NAME}/buildWithParameters?${BUILD_PARAMS}"
else
    TRIGGER_PATH="job/${JOB_NAME}/build"
fi

log_info "Triggering job '${JOB_NAME}' on ${JENKINS_URL}..."

QUEUE_LOCATION=$(curl --silent --fail --show-error \
    --write-out "%{header_json}" --output /dev/null \
    "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}" \
    -X POST "${JENKINS_URL}/${TRIGGER_PATH}" \
    | python3 -c "import sys,json; h=json.load(sys.stdin); print(h.get('location',[''])[0].strip('/'))" 2>/dev/null || echo "")

log_info "Job triggered. Queue location: ${QUEUE_LOCATION:-unknown}"

if ! "$WAIT_FOR_COMPLETION" || [[ -z "$QUEUE_LOCATION" ]]; then
    exit 0
fi

log_info "Waiting for build to complete (polling every ${POLL_INTERVAL}s)..."

while true; do
    BUILD_URL=$(curl --silent "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}" \
        "${QUEUE_LOCATION}/api/json" \
        | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('executable',{}).get('url',''))" 2>/dev/null || echo "")

    if [[ -z "$BUILD_URL" ]]; then
        log_info "Still queued..."
        sleep "$POLL_INTERVAL"
        continue
    fi

    RESULT=$(curl --silent "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}" \
        "${BUILD_URL}api/json" \
        | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',''))" 2>/dev/null || echo "")

    if [[ -z "$RESULT" || "$RESULT" == "None" ]]; then
        log_info "Build running at ${BUILD_URL}..."
        sleep "$POLL_INTERVAL"
        continue
    fi

    case "$RESULT" in
        SUCCESS) log_info "Build completed: ${RESULT}"; exit 0 ;;
        *)       log_error "Build completed: ${RESULT}"; exit 2 ;;
    esac
done
