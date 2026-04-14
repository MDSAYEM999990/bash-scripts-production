#!/bin/bash
# k8s-pod-logs-export.sh — Export logs from all pods in a namespace to files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "${SCRIPT_DIR}/../lib/utils.sh"

NAMESPACE=""
OUTPUT_DIR="./pod-logs"
SINCE=""
TAIL_LINES=""
CONTAINER=""
DRY_RUN=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Export logs from all pods (or a specific pod) in a Kubernetes namespace to
individual files in an output directory.

Options:
  --namespace NS      Kubernetes namespace to export logs from    (required)
  --output-dir DIR    Directory to write log files to             (default: ./pod-logs)
  --since DURATION    Only return logs newer than this duration   (e.g. 1h, 30m)
  --tail N            Number of most recent lines per container
  --container NAME    Export only this container (default: all)
  --dry-run           Show what would be exported, make no changes
  -h, --help          Show this help message

Examples:
  $(basename "$0") --namespace production
  $(basename "$0") --namespace staging --since 2h --output-dir /tmp/logs
  $(basename "$0") --namespace default --tail 100 --dry-run
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --namespace)   NAMESPACE="$2";   shift 2 ;;
        --output-dir)  OUTPUT_DIR="$2";  shift 2 ;;
        --since)       SINCE="$2";       shift 2 ;;
        --tail)        TAIL_LINES="$2";  shift 2 ;;
        --container)   CONTAINER="$2";   shift 2 ;;
        --dry-run)     DRY_RUN=true;     shift ;;
        -h|--help)     usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

if [[ -z "$NAMESPACE" ]]; then
    log_error "A namespace is required."
    usage
    exit 1
fi

check_dependency kubectl

log_info "Fetching pods in namespace '${NAMESPACE}'..."
PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers -o custom-columns=":metadata.name" 2>/dev/null) || {
    log_error "Failed to list pods in namespace '${NAMESPACE}'."
    exit 2
}

if [[ -z "$PODS" ]]; then
    log_warn "No pods found in namespace '${NAMESPACE}'."
    exit 0
fi

if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[dry-run] Would export logs to '${OUTPUT_DIR}/' for pods:"
    echo "$PODS"
    exit 0
fi

mkdir -p "$OUTPUT_DIR"

# Build shared kubectl logs flags
LOG_FLAGS=(-n "$NAMESPACE")
[[ -n "$SINCE" ]]       && LOG_FLAGS+=(--since="$SINCE")
[[ -n "$TAIL_LINES" ]]  && LOG_FLAGS+=(--tail="$TAIL_LINES")
[[ -n "$CONTAINER" ]]   && LOG_FLAGS+=(-c "$CONTAINER")

EXPORTED=0
while IFS= read -r pod; do
    [[ -z "$pod" ]] && continue
    OUTFILE="${OUTPUT_DIR}/${pod}.log"
    log_info "Exporting: ${pod} → ${OUTFILE}"
    if kubectl logs "${LOG_FLAGS[@]}" "$pod" > "$OUTFILE" 2>&1; then
        (( EXPORTED++ )) || true
    else
        log_warn "Failed to export logs for pod '${pod}' — skipping."
    fi
done <<< "$PODS"

log_info "Exported logs for ${EXPORTED} pod(s) to '${OUTPUT_DIR}/'."
exit 0
