#!/bin/bash
# argo-cd-sync.sh — Trigger an ArgoCD application sync via the REST API.
# Usage: ./argo-cd-sync.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

ARGOCD_SERVER="${ARGOCD_SERVER:-argocd.example.com}"
ARGOCD_APP="${ARGOCD_APP:-my-app}"
ARGOCD_TOKEN="${ARGOCD_TOKEN:-}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Trigger a sync for an ArgoCD application.

Options:
  --server HOST    ArgoCD server hostname (env: ARGOCD_SERVER, default: ${ARGOCD_SERVER})
  --app    NAME    Application name       (env: ARGOCD_APP,    default: ${ARGOCD_APP})
  --token  TOKEN   Bearer token           (env: ARGOCD_TOKEN)
  -h, --help       Show this help message

Examples:
  ARGOCD_TOKEN=mytoken $(basename "$0") --server argocd.example.com --app my-app
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --server) ARGOCD_SERVER="$2"; shift 2 ;;
        --app)    ARGOCD_APP="$2";    shift 2 ;;
        --token)  ARGOCD_TOKEN="$2";  shift 2 ;;
        -h|--help) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

check_dependency curl

if [[ -z "$ARGOCD_TOKEN" ]]; then
    log_error "ARGOCD_TOKEN must be set via --token or the ARGOCD_TOKEN environment variable."
    exit 1
fi

log_info "Triggering sync for application '${ARGOCD_APP}' on ${ARGOCD_SERVER}..."

curl --fail --silent --show-error \
     -X POST "https://${ARGOCD_SERVER}/api/v1/applications/${ARGOCD_APP}/sync" \
     -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
     -H "Content-Type: application/json"

log_info "Sync triggered successfully for '${ARGOCD_APP}'."
