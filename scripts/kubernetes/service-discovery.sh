#!/bin/bash
# service-discovery.sh — List all services in a Kubernetes namespace with endpoints
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "${SCRIPT_DIR}/../lib/utils.sh"

NAMESPACE="default"
OUTPUT_FORMAT="table"
FILTER_TYPE=""
SHOW_ENDPOINTS=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

List all Kubernetes services in a namespace, showing type, cluster IP, ports,
and optionally the backing endpoint IPs.

Options:
  --namespace NS      Kubernetes namespace to inspect   (default: default)
  --type TYPE         Filter by service type: ClusterIP|NodePort|LoadBalancer
  --show-endpoints    Also show the pod endpoint IPs for each service
  --output FORMAT     Output format: table or json       (default: table)
  -h, --help          Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --namespace production --show-endpoints
  $(basename "$0") --namespace staging --type LoadBalancer
  $(basename "$0") --namespace default --output json
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --namespace)      NAMESPACE="$2";      shift 2 ;;
        --type)           FILTER_TYPE="$2";    shift 2 ;;
        --show-endpoints) SHOW_ENDPOINTS=true; shift ;;
        --output)         OUTPUT_FORMAT="$2";  shift 2 ;;
        -h|--help)        usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

check_dependency kubectl

log_info "Discovering services in namespace '${NAMESPACE}'..."

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    kubectl get services -n "$NAMESPACE" -o json
    exit 0
fi

# Table output
KUBECTL_ARGS=(get services -n "$NAMESPACE" --no-headers)
[[ -n "$FILTER_TYPE" ]] && KUBECTL_ARGS+=(--field-selector "spec.type=${FILTER_TYPE}")

printf '%-40s %-16s %-16s %-30s\n' "NAME" "TYPE" "CLUSTER-IP" "PORT(S)"
printf '%-40s %-16s %-16s %-30s\n' "----" "----" "----------" "-------"

kubectl "${KUBECTL_ARGS[@]}" \
    -o custom-columns="NAME:.metadata.name,TYPE:.spec.type,IP:.spec.clusterIP,PORTS:.spec.ports[*].port" \
    2>/dev/null | while IFS= read -r line; do
    printf '%s\n' "$line"
done

if [[ "$SHOW_ENDPOINTS" == "true" ]]; then
    echo ""
    log_info "Endpoints:"
    printf '%-40s %-s\n' "SERVICE" "ENDPOINT IPs"
    printf '%-40s %-s\n' "-------" "------------"
    kubectl get endpoints -n "$NAMESPACE" --no-headers \
        -o custom-columns="NAME:.metadata.name,ADDRESSES:.subsets[*].addresses[*].ip" \
        2>/dev/null | while IFS= read -r line; do
        printf '%s\n' "$line"
    done
fi

exit 0
