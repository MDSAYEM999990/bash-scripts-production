#!/bin/bash
# scale-deployment.sh — Scale a Kubernetes deployment to a target replica count.
# Usage: ./scale-deployment.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

DEPLOYMENT="${DEPLOYMENT:-}"
REPLICAS="${REPLICAS:-}"
NAMESPACE="${NAMESPACE:-default}"
CONTEXT="${KUBE_CONTEXT:-}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Scale a Kubernetes Deployment to the specified replica count and wait for rollout.

Options:
  --deployment NAME    Deployment name          (env: DEPLOYMENT)
  --replicas   N       Target replica count     (env: REPLICAS)
  --namespace  NS      Kubernetes namespace     (env: NAMESPACE,   default: ${NAMESPACE})
  --context    CTX     Kubernetes context       (env: KUBE_CONTEXT)
  -h, --help           Show this help message

Examples:
  $(basename "$0") --deployment my-app --replicas 3
  $(basename "$0") --deployment api --replicas 0 --namespace staging
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --deployment) DEPLOYMENT="$2"; shift 2 ;;
        --replicas)   REPLICAS="$2";   shift 2 ;;
        --namespace)  NAMESPACE="$2";  shift 2 ;;
        --context)    CONTEXT="$2";    shift 2 ;;
        -h|--help)    usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

check_dependency kubectl

if [[ -z "$DEPLOYMENT" ]]; then
    log_error "--deployment (or env var DEPLOYMENT) is required."
    exit 1
fi
if [[ -z "$REPLICAS" ]]; then
    log_error "--replicas (or env var REPLICAS) is required."
    exit 1
fi

KUBECTL_OPTS=(--namespace "$NAMESPACE")
[[ -n "$CONTEXT" ]] && KUBECTL_OPTS+=(--context "$CONTEXT")

log_info "Scaling deployment '${DEPLOYMENT}' in namespace '${NAMESPACE}' to ${REPLICAS} replica(s)..."
kubectl "${KUBECTL_OPTS[@]}" scale deployment "$DEPLOYMENT" --replicas="$REPLICAS"

log_info "Waiting for rollout to complete..."
kubectl "${KUBECTL_OPTS[@]}" rollout status deployment/"$DEPLOYMENT" --timeout=5m

log_info "Deployment '${DEPLOYMENT}' scaled to ${REPLICAS} replica(s) successfully."
