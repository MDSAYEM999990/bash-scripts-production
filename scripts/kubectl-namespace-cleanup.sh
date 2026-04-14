#!/bin/bash
# kubectl-namespace-cleanup.sh — Delete kubernetes namespaces that have been Terminating for too long.
# Usage: ./kubectl-namespace-cleanup.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

DRY_RUN=false
CONTEXT="${KUBE_CONTEXT:-}"
STUCK_MINUTES=30

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Force-delete Kubernetes namespaces stuck in the Terminating phase by patching
their finalizers to nil, then deleting them.

Options:
  --dry-run            Print what would be done; make no changes
  --context  CTX       Kubernetes context       (env: KUBE_CONTEXT)
  --stuck-minutes MIN  Minimum minutes stuck before action (default: ${STUCK_MINUTES})
  -h, --help           Show this help message

Examples:
  $(basename "$0") --dry-run
  $(basename "$0") --context my-cluster --stuck-minutes 60
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)       DRY_RUN=true;        shift   ;;
        --context)       CONTEXT="$2";        shift 2 ;;
        --stuck-minutes) STUCK_MINUTES="$2";  shift 2 ;;
        -h|--help)       usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

check_dependency kubectl

KUBECTL_OPTS=()
[[ -n "$CONTEXT" ]] && KUBECTL_OPTS=(--context "$CONTEXT")

TERMINATING=$(kubectl "${KUBECTL_OPTS[@]+"${KUBECTL_OPTS[@]}"}" \
    get namespaces --field-selector=status.phase=Terminating \
    -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [[ -z "$TERMINATING" ]]; then
    log_info "No namespaces are stuck in Terminating phase."
    exit 0
fi

log_info "Found Terminating namespaces: ${TERMINATING}"
if "$DRY_RUN"; then
    log_warn "[DRY RUN] Would force-delete: ${TERMINATING}"
    exit 0
fi

confirm_action "Force-delete these namespaces? This is irreversible."

for ns in $TERMINATING; do
    log_info "Patching finalizers for namespace '${ns}'..."
    kubectl "${KUBECTL_OPTS[@]+"${KUBECTL_OPTS[@]}"}" \
        patch namespace "$ns" \
        -p '{"metadata":{"finalizers":null}}' \
        --type=merge

    log_info "Deleting namespace '${ns}'..."
    kubectl "${KUBECTL_OPTS[@]+"${KUBECTL_OPTS[@]}"}" \
        delete namespace "$ns" --grace-period=0 --force || true

    log_info "Namespace '${ns}' cleanup complete."
done
