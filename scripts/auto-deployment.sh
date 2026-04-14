#!/bin/bash
# auto-deployment.sh — Pull latest code and restart an application service.
# Usage: ./auto-deployment.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

REPO_DIR="${REPO_DIR:-/path/to/repo}"
SERVICE="${SERVICE:-myapp}"
BRANCH="${BRANCH:-main}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Pull the latest code from a git repository and restart the application service.

Options:
  --repo    DIR      Path to local git repository (env: REPO_DIR, default: ${REPO_DIR})
  --service NAME     Systemd service name          (env: SERVICE,   default: ${SERVICE})
  --branch  NAME     Branch to pull from           (default: ${BRANCH})
  -h, --help         Show this help message

Examples:
  $(basename "$0") --repo /opt/myapp --service myapp
  REPO_DIR=/opt/api SERVICE=api-server $(basename "$0")
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)    REPO_DIR="$2"; shift 2 ;;
        --service) SERVICE="$2";  shift 2 ;;
        --branch)  BRANCH="$2";   shift 2 ;;
        -h|--help) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

check_dependency git
check_dependency systemctl

if [[ ! -d "$REPO_DIR" ]]; then
    log_error "Repository directory not found: ${REPO_DIR}"
    exit 1
fi

cd "$REPO_DIR"

log_info "Pulling latest code from branch '${BRANCH}'..."
git pull origin "$BRANCH"
log_info "Code updated successfully."

log_info "Restarting service '${SERVICE}'..."
systemctl restart "$SERVICE"

if systemctl is-active --quiet "$SERVICE"; then
    log_info "'${SERVICE}' restarted successfully."
else
    log_error "'${SERVICE}' failed to start. Check: journalctl -u ${SERVICE}"
    exit 2
fi
