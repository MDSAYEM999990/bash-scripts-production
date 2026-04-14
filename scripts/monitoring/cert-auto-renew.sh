#!/bin/bash
# cert-auto-renew.sh — Run certbot renew and reload the web server on success
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "${SCRIPT_DIR}/../lib/utils.sh"

WEB_SERVER="nginx"
CERTBOT_FLAGS="--quiet"
DRY_RUN=false
NOTIFY_EMAIL="${CERT_NOTIFY_EMAIL:-}"
PRE_HOOK=""
POST_HOOK=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Run 'certbot renew' and reload the web server only when at least one
certificate was actually renewed.

Options:
  --web-server NAME   Web server to reload after renewal  (default: nginx)
                      Supported: nginx, apache2, haproxy
  --pre-hook CMD      Command to run before certbot renew
  --post-hook CMD     Command to run after a successful renewal
  --notify-email ADDR Send a renewal summary to this address  (env: CERT_NOTIFY_EMAIL)
  --dry-run           Pass --dry-run to certbot; do not reload server
  -h, --help          Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --web-server apache2 --notify-email ops@example.com
  $(basename "$0") --dry-run
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --web-server)    WEB_SERVER="$2";    shift 2 ;;
        --pre-hook)      PRE_HOOK="$2";      shift 2 ;;
        --post-hook)     POST_HOOK="$2";     shift 2 ;;
        --notify-email)  NOTIFY_EMAIL="$2";  shift 2 ;;
        --dry-run)       DRY_RUN=true; CERTBOT_FLAGS="${CERTBOT_FLAGS} --dry-run"; shift ;;
        -h|--help)       usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

check_dependency certbot

case "$WEB_SERVER" in
    nginx|apache2|haproxy) ;;
    *) log_error "Unsupported web server: '${WEB_SERVER}'. Use nginx, apache2, or haproxy."; exit 1 ;;
esac

[[ -n "$PRE_HOOK" ]] && { log_info "Running pre-hook: ${PRE_HOOK}"; eval "$PRE_HOOK"; }

# shellcheck disable=SC2086
RENEW_OUTPUT=$(certbot renew ${CERTBOT_FLAGS} 2>&1) || {
    log_error "certbot renew failed."
    echo "$RENEW_OUTPUT" >&2
    exit 2
}

echo "$RENEW_OUTPUT"

if echo "$RENEW_OUTPUT" | grep -q "Congratulations, all renewals succeeded"; then
    log_info "Certificate(s) renewed. Reloading ${WEB_SERVER}..."
    if [[ "$DRY_RUN" == "false" ]]; then
        systemctl reload "$WEB_SERVER" || service "$WEB_SERVER" reload || log_warn "Could not reload ${WEB_SERVER}."
    fi

    [[ -n "$POST_HOOK" ]] && { log_info "Running post-hook: ${POST_HOOK}"; eval "$POST_HOOK"; }

    if [[ -n "$NOTIFY_EMAIL" ]]; then
        echo "$RENEW_OUTPUT" | mail -s "TLS certificate renewed on $(hostname)" "$NOTIFY_EMAIL" 2>/dev/null \
            || log_warn "Could not send renewal notification email."
    fi
    log_info "Renewal complete."
elif echo "$RENEW_OUTPUT" | grep -q "No renewals were attempted"; then
    log_info "No certificates are due for renewal."
else
    log_warn "Unexpected certbot output — check the log above."
fi

exit 0
